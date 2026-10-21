import os, json, time, datetime, traceback, contextvars

from config import EVENT_DIR, EVENT_KEEP_DAYS, SLOW_SEC, log

# -----------------------------------------------------------
# 이벤트 기록 (오류 · 이상 상황만)
# -----------------------------------------------------------

_REQ = contextvars.ContextVar("callping_req", default=None)   # 요청별 정보 — 기록할 때 꺼내 쓴다


def _mkdir700(path):
    os.makedirs(path, mode=0o700, exist_ok=True)
    try:
        os.chmod(path, 0o700)
    except OSError:
        pass


# 보관 기간 지난 기록 삭제
def _purge_events(now=None):
    try:
        if not os.path.isdir(EVENT_DIR):
            return 0
        cut = (now or time.time()) - EVENT_KEEP_DAYS * 86400
        n = 0
        for d in os.listdir(EVENT_DIR):
            dp = os.path.join(EVENT_DIR, d)
            if not os.path.isdir(dp):
                continue
            for f in os.listdir(dp):
                fp = os.path.join(dp, f)
                try:
                    if os.path.isfile(fp) and os.path.getmtime(fp) < cut:
                        os.remove(fp)
                        n += 1
                except OSError:
                    pass
            try:
                if not os.listdir(dp):
                    os.rmdir(dp)
            except OSError:
                pass
        return n
    except Exception:
        log.warning("이벤트 정리 실패", exc_info=True)
        return 0


def _jsonable(x):
    if isinstance(x, (bytes, bytearray)):
        return bytes(x).decode("utf-8", errors="replace")
    return x


# 이벤트 파일 하나 쓰기 (실패해도 응답에는 영향 없음)
def capture(kind, status, body, state, exc=None, model_output=None, extra=None):
    try:
        _mkdir700(EVENT_DIR)
        now = datetime.datetime.now()
        day = os.path.join(EVENT_DIR, now.strftime("%Y-%m-%d"))
        _mkdir700(day)
        rec = {"ts": now.isoformat(timespec="milliseconds"), "kind": kind, "status": status,
               "state": state, "body": _jsonable(body)}
        if exc is not None:
            rec["error"] = {"type": type(exc).__name__,
                            "msg": str(getattr(exc, "detail", exc)),
                            "trace": "".join(traceback.format_exception(
                                type(exc), exc, exc.__traceback__))}
        if model_output is not None:
            rec["model_output"] = model_output
        if extra:
            rec["extra"] = extra
        path = os.path.join(day, f"{now.strftime('%H%M%S_%f')}_{status}_{kind}.json")
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(rec, f, ensure_ascii=False, indent=1, default=str)
        log.warning(f"event kind={kind} status={status} file={path}")
        _purge_events()
        return path
    except Exception:
        try:
            log.warning(f"event 캡처 실패 kind={kind} status={status}", exc_info=True)
        except Exception:
            pass
        return None


# 응답 직전: 느린 응답 · 연결 끊김 기록
async def _check_tail(request, ctx):
    try:
        st = ctx["state"]
        tot = sum(st.get(k) or 0 for k in ("wait", "gen", "todos_wait", "todos_gen", "summary_gen"))
        st["total"] = round(tot, 2)
        if tot > SLOW_SEC:
            capture("slow", 200, ctx["body"], st)
        if st.get("gone_at"):
            return
        if await request.is_disconnected():
            capture("client_gone", 200, ctx["body"], st)
    except Exception:
        log.warning("응답 직전 점검 실패", exc_info=True)
