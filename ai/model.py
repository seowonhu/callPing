import time, asyncio, torch
from fastapi import HTTPException
from transformers import AutoTokenizer, AutoModelForCausalLM, StoppingCriteria, StoppingCriteriaList
from peft import PeftModel

from config import BASE, ADAPTER_PATHS, ADAPTER_NAMES, ROUTE, _adapter_desc, GEN_TIMEOUT, log
from events import _REQ, capture

# -----------------------------------------------------------
# 모델 · 생성
# -----------------------------------------------------------

S = {}                             # 로드된 토크나이저 · 모델 — 서버 시작 때 채운다


def _cuda_mem():
    try:
        return torch.cuda.memory_allocated() if torch.cuda.is_available() else None
    except Exception:
        return None


# 베이스 모델 + 어댑터 로드 — 서버 시작 때 한 번
def load_model():
    t0 = time.time()
    tok = AutoTokenizer.from_pretrained(BASE)
    if tok.pad_token_id is None:
        tok.pad_token = tok.eos_token
    m = AutoModelForCausalLM.from_pretrained(BASE, device_map="cuda:0")
    loaded = {}                                       # 같은 경로는 한 번만
    for route in ("feedback", "guide"):
        name, path = ADAPTER_NAMES[route], ADAPTER_PATHS[route]
        if name in loaded:
            continue
        if not loaded:
            m = PeftModel.from_pretrained(m, path, adapter_name=name)
        else:
            m.load_adapter(path, adapter_name=name)
        loaded[name] = path
    m.set_adapter(ADAPTER_NAMES["feedback"])
    m.eval()
    S["tok"], S["model"] = tok, m
    S["adapter_active"] = ADAPTER_NAMES["feedback"]
    log.info(f"모델 로드 완료 {time.time()-t0:.1f}초  adapters={_adapter_desc()}  names={ADAPTER_NAMES}  "
             f"cuda_mem_alloc={_cuda_mem()}")


# 시간이 지나면 생성 멈춤
class _Deadline(StoppingCriteria):

    def __init__(self, deadline):
        self.deadline = deadline
        self.hit = False

    def __call__(self, input_ids, scores, **kw):
        stop = time.time() >= self.deadline
        self.hit = self.hit or stop
        return torch.full((input_ids.shape[0],), stop, dtype=torch.bool, device=input_ids.device)


# 어댑터 전환 (GPU 락 안에서) — 걸린 초
def _use_adapter(name: str) -> float:
    if S.get("adapter_active") == name:
        return 0.0
    t = time.time()
    S["model"].set_adapter(name)
    S["adapter_active"] = name
    return round(time.time() - t, 4)


def _generate(instr: str, text: str, max_new: int, deadline: float, adapter: str = None):
    tok, model = S["tok"], S["model"]
    switch = _use_adapter(adapter) if adapter else 0.0
    prompt = f"### 지시:\n{instr}\n\n### 입력:\n{text}\n\n### 응답:\n"
    ids = tok(prompt, return_tensors="pt").to("cuda")
    dl = _Deadline(deadline)
    with torch.no_grad():
        out = model.generate(**ids, max_new_tokens=max_new, do_sample=False,
                             pad_token_id=tok.pad_token_id,
                             stopping_criteria=StoppingCriteriaList([dl]))
    return tok.decode(out[0][ids["input_ids"].shape[1]:], skip_special_tokens=True).strip(), dl.hit, switch


# 생성 한 단계 (gpu_slot 안에서 호출)
async def gen_step(instr: str, text: str, kind: str, max_new: int):
    ctx = _REQ.get() or {}
    st, body = ctx.get("state", {}), ctx.get("body")
    p = "" if kind in ("guide", "feedback") else kind + "_"
    own = p == ""
    adapter = ADAPTER_NAMES[ROUTE[kind]]           # 단계별 어댑터
    t = time.time()
    try:
        result, hit, switch = await asyncio.wait_for(
            asyncio.to_thread(_generate, instr, text, max_new, t + GEN_TIMEOUT, adapter),
            timeout=GEN_TIMEOUT + 15)
        st[p + "adapter"] = adapter
        st[p + "switch"] = switch
        if hit:
            raise asyncio.TimeoutError(f"GEN_TIMEOUT {GEN_TIMEOUT}s")
    except asyncio.TimeoutError as e:
        st[p + "gen"] = round(time.time() - t, 2)
        if own:
            capture("timeout", 504, body, st, exc=e)
        raise HTTPException(504, "생성 시간이 초과되었습니다")
    except torch.cuda.OutOfMemoryError as e:
        st[p + "gen"] = round(time.time() - t, 2)
        st[p + "cuda_mem_at_oom"] = _cuda_mem()
        torch.cuda.empty_cache()
        if own:
            capture("oom", 503, body, st, exc=e)
        raise HTTPException(503, "서버가 혼잡합니다. 잠시 후 다시 시도해 주세요")
    except Exception as e:
        st[p + "gen"] = round(time.time() - t, 2)
        log.exception(f"{kind} 생성 실패")
        if own:
            capture("gen_error", 500, body, st, exc=e)
        raise HTTPException(500, f"생성 실패: {type(e).__name__}")
    sec = round(time.time() - t, 2)
    st[p + "gen"] = sec
    st[p + "out"] = len(result)
    return result, sec
