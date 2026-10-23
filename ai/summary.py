import re

from config import SUMMARY_MAX_CHARS

# -----------------------------------------------------------
# 통화 요약 검사 (형식 · 길이 · 날조 · 과장)
# -----------------------------------------------------------

_SUM_LABELS = (("목적", r"(?:통화\s*)?목적"), ("결과", r"(?:통화\s*)?결과"), ("다음 할 일", r"다음\s*할\s*일"))
_KO_HOUR = {"한": 1, "두": 2, "세": 3, "네": 4, "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9,
            "열": 10, "열한": 11, "열두": 12}
_SUM_NUM = re.compile(r"\d[\d,.:/~-]*")
_SUM_KNUM = re.compile(r"(?:한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|스무)\s?(?:시간|분|일|달|개월|번|개|명|장|건|주)")
_SUM_DATE = re.compile(r"오늘|내일|모레|어제|그제|이번\s?주|다음\s?주|다음\s?달|이번\s?달|주말|평일|"
                       r"[월화수목금토일]요일|오전|오후|저녁|아침")
_SUM_PROPER = ("은행", "카드", "병원", "의원", "센터", "마트", "백화점", "보험", "통신", "택배", "공단", "구청",
               "시청", "주민센터", "학교", "약국", "호텔", "항공", "지점", "아파트", "빌딩")
_SUM_WORD = re.compile(r"[가-힣A-Za-z][가-힣A-Za-z0-9]+")
_SUM_DONE = re.compile(r"완료|확정|처리\s?됨|처리\s?되었|처리\s?됐|변경\s?됨|변경\s?되었|변경\s?됐|"
                       r"예약\s?됨|예약\s?되었|예약\s?됐|접수\s?됨|접수\s?되었|접수\s?됐")
_SUM_DONE_OK = re.compile(r"(?:확인|안내|문의|상담|설명)\s?(?:완료|됨)")
_AGENT_DONE = re.compile(r"완료|확정|드렸|되었습니다|됐습니다|도와\s?드리겠|해\s?드리겠|잡아\s?드리겠|"
                         r"처리해\s?드리|처리\s?도와|접수\s?(?:되|해|도와)|예약\s?(?:되|해\s?드리|도와\s?드리겠)")


# '세 시' → '3시'
def _ko_digits(s: str) -> str:
    return re.sub(r"(열한|열두|다섯|여섯|일곱|여덟|아홉|한|두|세|네|열)\s?시(?!간)",
                  lambda m: f"{_KO_HOUR[m.group(1)]}시", s)


# 화자 라벨을 뺀 전사본 본문
def _transcript_body(joined: str) -> str:
    return "\n".join(re.sub(r"^\d+:\s?", "", l) for l in joined.split("\n"))


def _summary_lines(text: str):
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.S).strip()
    got = {}
    for line in text.split("\n"):
        line = line.strip().strip("-•*").strip()
        for key, pat in _SUM_LABELS:
            m = re.match(r"^\[?\s*" + pat + r"\s*\]?\s*[:：]?\s*(.+)$", line)
            if m and key not in got:
                got[key] = m.group(1).strip()
                break
    return got


# 검사에 걸리면 빈 요약
def check_summary(raw: str, joined: str):
    info = {}
    parts = _summary_lines(raw)
    if len(parts) < 3:
        return "", "format", {"found": sorted(parts)}
    summary = (f"통화 목적: {parts['목적']}\n결과: {parts['결과']}\n다음 할 일: {parts['다음 할 일']}")
    info["chars"] = len(summary.replace("\n", ""))
    if info["chars"] > SUMMARY_MAX_CHARS:
        return "", "too_long", info
    body = re.sub(r"\s+", "", _ko_digits(_transcript_body(joined)))
    s = _ko_digits(summary)
    cands = set()
    for m in _SUM_NUM.finditer(s):
        cands.add(m.group().strip(".,-/:~"))
    for rx in (_SUM_KNUM, _SUM_DATE):
        cands.update(m.group() for m in rx.finditer(s))
    for w in _SUM_WORD.findall(s):
        if re.match(r"[A-Za-z]{2,}", w) or (len(w) >= 3 and w.endswith(_SUM_PROPER)):
            cands.add(w)
    missing = sorted(c for c in cands if c and re.sub(r"\s+", "", c) not in body)
    info["checked"] = sorted(c for c in cands if c)
    if missing:
        info["missing"] = missing
        return "", "fabricated", info
    claims = _SUM_DONE.findall(_SUM_DONE_OK.sub("", parts["결과"]))
    if claims:
        agent = " ".join(re.sub(r"^1:\s?", "", l) for l in joined.split("\n") if l.startswith("1:"))
        info["claims"] = claims
        if not _AGENT_DONE.search(agent):
            return "", "overclaim", info
    return summary, None, info
