import time, asyncio, collections
from contextlib import asynccontextmanager
from fastapi import HTTPException

from config import QUEUE_MAX
from events import _REQ, capture

# -----------------------------------------------------------
# GPU 락 (들어온 순서대로) · 대기열 — 파일 이름이 queue 가 아닌 건 표준 라이브러리 queue 와 겹치지 않게
# -----------------------------------------------------------

class _FifoLock:

    def __init__(self):
        self._locked = False
        self._waiters = collections.deque()

    def locked(self):
        return self._locked

    async def acquire(self):
        if not self._locked and not self._waiters:
            self._locked = True
            return
        fut = asyncio.get_running_loop().create_future()
        self._waiters.append(fut)
        try:
            await fut                      # 차례가 오면 깨어난다
        except asyncio.CancelledError:
            if fut.done() and not fut.cancelled():
                self.release()             # 받은 뒤 취소되면 다음 사람에게
            else:
                try:
                    self._waiters.remove(fut)
                except ValueError:
                    pass
            raise

    def release(self):
        while self._waiters:
            fut = self._waiters.popleft()
            if not fut.done():
                fut.set_result(True)       # 다음 대기자에게 바로 넘긴다
                return
        self._locked = False

    async def __aenter__(self):
        await self.acquire()
        return self

    async def __aexit__(self, *exc):
        self.release()


GPU_LOCK = _FifoLock()
_WAIT = {"n": 0}                   # 처리 중 + 대기 중인 요청 수


# 클라이언트가 연결을 끊었는지
async def _gone(request) -> bool:
    if request is None:
        return False
    try:
        return await request.is_disconnected()
    except Exception:
        return False


# 단계 사이에 끊겼으면 남은 단계 건너뜀
async def gone_between(request, stage: str) -> bool:
    if not await _gone(request):
        return False
    ctx = _REQ.get() or {}
    st = ctx.get("state", {})
    st["gone_at"] = stage
    capture("client_gone_mid", 499, ctx.get("body"), st, extra={"stage": stage})
    return True


# 대기열 확인 후 GPU 락 잡기
@asynccontextmanager
async def gpu_slot(request=None):
    ctx = _REQ.get() or {}
    st, body = ctx.get("state", {}), ctx.get("body")
    st["queue"] = _WAIT["n"]
    if _WAIT["n"] >= QUEUE_MAX:
        capture("queue_full", 503, body, st)
        raise HTTPException(503, "서버가 혼잡합니다. 잠시 후 다시 시도해 주세요")
    t = time.time()
    _WAIT["n"] += 1
    try:
        async with GPU_LOCK:
            st["wait"] = round(time.time() - t, 2)
            if await _gone(request):
                st["gone_at"] = "before_start"
                capture("client_gone_before_start", 499, body, st)
                raise HTTPException(499, "클라이언트가 먼저 끊었다 — 생성하지 않음")
            yield
    finally:
        _WAIT["n"] -= 1
