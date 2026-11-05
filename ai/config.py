import os, logging

# -----------------------------------------------------------
# 설정
# -----------------------------------------------------------

BASE = "unsloth/Qwen3-8B-unsloth-bnb-4bit"

# LoRA 어댑터 경로 (환경변수로 지정)
ADAPTER = os.environ.get("CALLPING_ADAPTER") or "<CALLPING_ADAPTER>"

# 경로별 어댑터 — 가이드 / 피드백 · 할 일 · 요약 (지정 안 하면 ADAPTER 하나로 둘 다)
ADAPTER_PATHS = {"guide": os.environ.get("CALLPING_ADAPTER_GUIDE") or ADAPTER,
                 "feedback": os.environ.get("CALLPING_ADAPTER_FEEDBACK") or ADAPTER}
ROUTE = {"guide": "guide", "feedback": "feedback", "todos": "feedback", "summary": "feedback"}   # 생성 단계 → 어댑터 경로


# 경로 → 어댑터 이름 (두 경로가 같으면 default 하나)
def _adapter_names():
    if os.path.normpath(ADAPTER_PATHS["guide"]) == os.path.normpath(ADAPTER_PATHS["feedback"]):
        return {"guide": "default", "feedback": "default"}
    return {"guide": "guide", "feedback": "feedback"}


ADAPTER_NAMES = _adapter_names()


# 기록 · health 용 어댑터 이름
def _adapter_desc():
    return {k: os.path.basename(os.path.normpath(v)) for k, v in ADAPTER_PATHS.items()}


API_KEY = os.environ.get("CALLPING_API_KEY", "")
API_VERSION = "2.6.0"
MAX_INPUT = 4000
GEN_TIMEOUT = 90                   # 생성 한 단계의 최대 시간(초)
QUEUE_MAX = 8                      # 처리 1 + 대기 7, 넘치면 503

SUMMARY_MAX_NEW = 160
SUMMARY_MAX_CHARS = 120

# 이벤트 기록 위치 · 보관 기간
EVENT_DIR = os.environ.get("CALLPING_EVENT_DIR") or os.path.expanduser("~/callping/logs/events")
EVENT_KEEP_DAYS = 14
SLOW_SEC = 60                      # 이보다 오래 걸리면 기록

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("callping")
