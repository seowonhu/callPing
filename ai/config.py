import os, logging

# -----------------------------------------------------------
# 설정
# -----------------------------------------------------------

BASE = "unsloth/Qwen3-8B-unsloth-bnb-4bit"

# LoRA 어댑터 경로 (환경변수로 지정)
ADAPTER = os.environ.get("CALLPING_ADAPTER") or "<CALLPING_ADAPTER>"

API_KEY = os.environ.get("CALLPING_API_KEY", "")
API_VERSION = "2.5.1"
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
