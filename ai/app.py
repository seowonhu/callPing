import time
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.exceptions import RequestValidationError
from fastapi.exception_handlers import request_validation_exception_handler
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field

from config import ADAPTER, API_KEY, API_VERSION, MAX_INPUT, SUMMARY_MAX_NEW, EVENT_DIR, EVENT_KEEP_DAYS, log
from prompts import SUM, G, F, T
from events import _REQ, _mkdir700, _purge_events, capture, _check_tail
from model import S, _cuda_mem, load_model, gen_step
from gpu_queue import GPU_LOCK, _WAIT, gpu_slot, gone_between
from speakers import normalize_speakers, _note_transcript
from parsing import split_sections, render_guide, split_feedback, _parse_todos_detail, public_todo, todo_summary
from summary import check_summary

# -----------------------------------------------------------
# 요청 정보
# -----------------------------------------------------------

# 기록에 남길 서버 상태
def _base_state():
    st = {"adapter": ADAPTER.split("/")[-1], "api_version": API_VERSION,
          "queue": _WAIT["n"], "cuda_mem_alloc": _cuda_mem()}
    try:
        st["gpu_busy"] = GPU_LOCK.locked()
    except Exception:
        pass
    return st


# 요청 정보 저장
def _begin(endpoint, req):
    try:
        body = req.model_dump()
    except Exception:
        body = None
    ctx = {"endpoint": endpoint, "body": body, "state": _base_state()}
    _REQ.set(ctx)
    return ctx


# 입력 검사 (빈 입력 · 너무 긺 · 모델 로딩 중)
def check_input(text: str):
    ctx = _REQ.get() or {}
    st, body = ctx.get("state", {}), ctx.get("body")
    text = (text or "").strip()
    st["in"] = len(text)
    if not text:
        capture("empty_input", 400, body, st)
        raise HTTPException(400, "입력이 비어 있습니다")
    if len(text) > MAX_INPUT:
        capture("too_long", 400, body, st)
        raise HTTPException(400, f"입력이 너무 깁니다 (최대 {MAX_INPUT}자)")
    if "model" not in S:
        capture("loading", 503, body, st)
        raise HTTPException(503, "모델 로딩 중입니다")
    return text


def check_key(x_api_key):
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(401, "인증 실패")


# -----------------------------------------------------------
# 서버 시작 · 모델 로드
# -----------------------------------------------------------

@asynccontextmanager
async def lifespan(app):
    try:
        _mkdir700(EVENT_DIR)
        n = _purge_events()
        log.info(f"이벤트 디렉터리 {EVENT_DIR}  ({EVENT_KEEP_DAYS}일 경과 {n}건 삭제)")
    except Exception:
        log.warning("이벤트 디렉터리 준비 실패", exc_info=True)
    load_model()
    yield
    S.clear()


app = FastAPI(title="CallPing LoRA API", version=API_VERSION, lifespan=lifespan)


# 요청 형식 오류(422) 기록
@app.exception_handler(RequestValidationError)
async def _on_invalid(request: Request, exc: RequestValidationError):
    try:
        errs = [{"loc": list(e.get("loc", ())), "type": e.get("type"), "msg": e.get("msg")}
                for e in exc.errors()]
        capture("validation", 422, getattr(exc, "body", None), _base_state(),
                extra={"path": request.url.path, "errors": errs})
    except Exception:
        log.warning("422 캡처 실패", exc_info=True)
    return await request_validation_exception_handler(request, exc)


# 처리 안 된 예외 → 500
@app.exception_handler(Exception)
async def _on_unhandled(request: Request, exc: Exception):
    try:
        ctx = _REQ.get() or {}
        capture("unhandled", 500, ctx.get("body"), ctx.get("state") or _base_state(),
                exc=exc, extra={"path": request.url.path})
    except Exception:
        pass
    return PlainTextResponse("Internal Server Error", status_code=500)


# -----------------------------------------------------------
# API
# -----------------------------------------------------------

class Turn(BaseModel):
    speaker: str
    text: str


class GuideReq(BaseModel):
    situation: str = Field(..., examples=["병원 예약"])


class FeedbackReq(BaseModel):
    transcript: list[Turn] = Field(..., min_length=1)


def _health():
    return {"status": "ok" if "model" in S else "loading",
            "adapter": ADAPTER.split("/")[-1],
            "auth_required": bool(API_KEY),
            "api_version": API_VERSION}


@app.get("/health")
def health_alias():
    return _health()


@app.get("/lora/health")
def health():
    return _health()


# 통화 전 가이드
@app.post("/lora/guides")
async def guides(req: GuideReq, request: Request, x_api_key: str | None = Header(None)):
    check_key(x_api_key)
    ctx = _begin("guides", req)
    situation = check_input(req.situation)
    t0 = time.time()
    async with gpu_slot(request):
        text, _ = await gen_step(G, situation, "guide", max_new=420)
    sec = round(time.time() - t0, 2)
    guide_text, script, tips = render_guide(text)
    if not tips:
        log.warning(f"가이드 4구조 파싱 실패 — 전체를 대본으로 폴백 (out={len(text)}자)")
    st = ctx["state"]
    log.info(f"guide wait={st.get('wait')} gen={st.get('gen')} in={st.get('in')} "
             f"out={st.get('out')} queue={st.get('queue')}")
    await _check_tail(request, ctx)
    return {"guide": guide_text, "script": script, "tips": tips, "elapsed": sec}


# 통화 후 피드백 + 할 일 + 요약
@app.post("/lora/feedback")
async def feedback(req: FeedbackReq, request: Request, x_api_key: str | None = Header(None)):
    check_key(x_api_key)
    ctx = _begin("feedback", req)
    st = ctx["state"]
    turns = normalize_speakers(req.transcript)
    joined = "\n".join(f"{spk}: {txt}" for spk, txt in turns)
    _note_transcript(st, turns, req.transcript)
    joined = check_input(joined)
    t0 = time.time()

    # 피드백 → 할 일 → 요약을 락 한 번에 (할 일 · 요약이 실패해도 피드백은 응답)
    t_text, s_raw, t_err, s_err = None, None, None, None
    skip_todos = skip_summary = False
    async with gpu_slot(request):
        text, _ = await gen_step(F, joined, "feedback", max_new=512)
        skip_todos = skip_summary = await gone_between(request, "after_feedback")
        if not skip_todos:
            try:
                t_text, _ = await gen_step(T, joined, "todos", max_new=200)
            except HTTPException as e:
                t_err = e
            skip_summary = await gone_between(request, "after_todos")
        if not skip_summary:
            try:
                s_raw, _ = await gen_step(SUM, joined, "summary", max_new=SUMMARY_MAX_NEW)
            except HTTPException as e:
                s_err = e
    elapsed = round(time.time() - t0, 2)

    expression, fb = split_sections(text)
    if expression is None:
        log.warning(f"2섹션 파싱 실패 — feedback 폴백 (out={len(text)}자)")
        capture("sections_fail", 200, ctx["body"], st, model_output=text)
    parts = split_feedback(expression, fb)

    todos = []
    if skip_todos:
        pass
    elif t_err is not None:
        log.warning(f"todos 생성 실패({t_err.status_code}) — 빈 배열로 응답: {t_err.detail}")
        capture("todos_fail", 200, ctx["body"], st, exc=t_err, extra={"inner_status": t_err.status_code})
    else:
        full, unparsed, dropped = _parse_todos_detail(t_text, joined)
        todos = [public_todo(td) for td in full]
        if unparsed:
            log.warning(f"todos 형식 이탈 {len(unparsed)}줄 — 첫 줄: {unparsed[0][:60]!r}")
        if dropped:
            log.info(f"todos 근거 필터 탈락 {len(dropped)}건 — "
                     f"{dropped[0]['why']}: {dropped[0]['line'][:60]!r}")
        if dropped and not full:
            capture("todos_filtered", 200, ctx["body"], st, model_output=t_text,
                    extra={"dropped": dropped, "unparsed": unparsed})

    summary = ""
    if skip_summary:
        pass
    elif s_err is not None:
        log.warning(f"요약 생성 실패({s_err.status_code}) — 빈 문자열로 응답: {s_err.detail}")
        capture("summary_fail", 200, ctx["body"], st, exc=s_err, extra={"inner_status": s_err.status_code})
    else:
        try:
            summary, why, info = check_summary(s_raw, joined)
            if why:
                st["summary_blocked"] = why
                capture("summary_blocked", 200, ctx["body"], st, model_output=s_raw,
                        extra={"why": why, **info})
        except Exception as e:
            summary = ""
            log.exception("요약 검사 실패")
            capture("summary_fail", 200, ctx["body"], st, exc=e, model_output=s_raw)

    spk = ",".join(f"{k}:{v}" for k, v in (st.get("speakers") or {}).items())
    log.info(f"feedback wait={st.get('wait')} gen={st.get('gen')} todos_gen={st.get('todos_gen')} "
             f"summary_gen={st.get('summary_gen')} in={st.get('in')} out={st.get('out')} "
             f"todos={len(todos)} summary={len(summary)} blocked={st.get('summary_blocked')} "
             f"turns={st.get('turns')} speakers={spk} max_run={st.get('max_run')} "
             f"queue={st.get('queue')} gone={st.get('gone_at')}")
    await _check_tail(request, ctx)
    return {"expression": expression, "feedback": fb, **parts,
            "todo_summary": todo_summary(len(todos)), "todos": todos,
            "summary": summary, "elapsed": elapsed}
