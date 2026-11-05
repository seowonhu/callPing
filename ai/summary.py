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
# 완료 근거 — 화자 번호로 역할(상담원 · 사용자)을 정하지 않는다. 전사본 **모든 화자의 문장**에서 내용으로 찾는다.
#   언급   완료 · 확정 · 예약 · 접수 · 처리 류 낱말. 그 뒤 몇 글자(같은 절)로 판정한다
#   제외   질문 · 부정 · 조건 · 추측 · 인용 · 요청(부탁드릴게요 · 해 주세요) · 결과 줄과 다른 대상 — 완료 근거로 인정하지 않는다
#   보류   약속(해 드리겠습니다) · '됩니다' · '~죠' · 뒤에 번복 표지가 나온 문장 — 규칙으로 못 가린다
#   인정   완료형 단정(됐습니다 · 했어요 · 해 드렸습니다 · 확정입니다)
#   판정   결과 줄 완료 주장이 있을 때 인정 1건 이상 → 통과, 보류만 → 통과 + info["overclaim"]="unresolved", 없으면 과장
#   근거에는 원문 문장과 화자 번호를 남기되 번호로 역할을 추정하지 않는다. (2026-10-29, v13 [0])
_EV_STEM = (r"완료|확정|예약|접수|처리|변경|취소|등록|발송|결제|신청|해지|환불|입금|예매|주문|배정|발급|연장|교체|"
            r"수리|이체|송금|배송")
_EV_WORDS = re.compile(_EV_STEM)
_EV_MENTION = re.compile(_EV_STEM + r"|(?<![가-힣])(?:다|모두|전부)\s?(?=되|됐)")
_EV_END = r"(?=$|[\s.?!,~])"
_EV_NEG = re.compile(r"않|안\s?(?:되|돼|됐|했|해)|못\s?(?:했|해|됐|되)|아직|미완료|^\s?(?:전|안)" + _EV_END)
_EV_NEG_HEAD = re.compile(r"(?:아직|안|못|미)\s*$")
_EV_QUESTION = re.compile(r"\?|(?:됐|했|되었|하였)니|(?:나요|까요|는지|냐|가요|는가|던가|습니까)" + _EV_END)
_EV_COND = re.compile(r"(?:되|돼|하|되시|하시|되셨으|하셨으|됐으|했으)면|는\s?대로|(?:될|할|된|한)\s?(?:때|경우|후|다음|뒤)|"
                      r"(?:되|돼|해|하)야")
_EV_GUESS = re.compile(r"것\s?같|거\s?같|듯|아마|(?:될|할|됐을|했을|을)\s?(?:거|걸)|겠죠|모르")
_EV_QUOTE = re.compile(r"(?:다|라|냐)고|대요|래요|답니다|다던|다는|라는|다네|다더")
_EV_REQUEST = re.compile(r"부탁|해\s?주세요|해\s?줘|해\s?주시|해\s?주실|해\s?달라")
_EV_NOT_DONE = re.compile(r"문의|확인|상담|여쭤|알아|궁금|싶|하려|려고|원하|할까|가능|방법|어떻게")
_EV_PROMISE = re.compile(r"드리겠|드릴게|드릴께|드릴\s?예정|줄게|해\s?줄|하겠|할게|할\s?예정|될\s?예정|됩니다|돼요|죠" + _EV_END)
# '완료되어 … 발송되었습니다' 의 연결형 '되어' 도 완료형 (조건 '되어야' 는 앞에서 이미 제외)
_EV_DONE = re.compile(r"되었|됐|되셨|돼\s?있|되어|했|하였|드렸|놨|놓았|뒀|두었")
_EV_DONE_NOUN = re.compile(r"\s?(?:상태\s?)?(?:입니다|이에요|예요|이고|이요)")
_EV_REVERSAL = re.compile(r"아니다|그거\s?말고|그게\s?아니라|말고요|취소(?:할게|해\s?주|하고|하겠)|"
                          r"다시\s?(?:확인|바꿔|변경|정하)|바꿀게|바꿔\s?(?:줘|주세요|주시)|변경(?:할게|해\s?주)|없던\s?걸로")
_EV_GENERIC = {"완료", "확정"}


# 결과 줄 완료 주장의 대상 — '예약 변경 완료' → {변경}, '접수됨' → {접수}. 못 찾으면 빈 집합(대상 무관)
def _claim_objects(res: str):
    res = _SUM_DONE_OK.sub("", res)
    objs = set()
    for m in _SUM_DONE.finditer(res):
        objs.update(_EV_WORDS.findall(m.group()))
        ws = _EV_WORDS.findall(res[max(0, m.start() - 8):m.start()])
        if ws:
            objs.add(ws[-1])
    return objs - _EV_GENERIC


# 언급 하나를 판정: (인정 · 제외 · 보류 · None, 이유)
def _ev_judge(sent: str, m, later: str, objs):
    word = m.group().strip()
    rest = sent[m.end():m.end() + 8]
    cut = re.search(r"[.!,]|는데|지만", rest)
    if cut:
        rest = rest[:cut.start()]
    q = rest.find("?")
    if q >= 0:
        rest = rest[:q + 1]
    head = sent[max(0, m.start() - 6):m.start()]
    if _EV_NEG_HEAD.search(head) or _EV_NEG.search(rest):
        return "제외", "부정"
    if _EV_QUESTION.search(rest):
        return "제외", "질문"
    if _EV_COND.search(rest):
        return "제외", "조건"
    if _EV_GUESS.search(head + word + rest):
        return "제외", "추측"
    if _EV_QUOTE.search(rest):
        return "제외", "인용"
    if _EV_REQUEST.search(rest):
        return "제외", "요청"
    if _EV_NOT_DONE.search(rest):
        return None, None
    if _EV_PROMISE.search(rest):
        st = ("보류", "약속 · 미래형 · 확인 어미")
    elif _EV_DONE.search(rest) or (word in _EV_GENERIC and (_EV_DONE_NOUN.match(rest) or not rest.strip(" ~"))):
        st = ("보류", "뒤에 번복 표지") if _EV_REVERSAL.search(later) else ("인정", None)
    else:
        return None, None
    if objs and word in _EV_WORDS.pattern.split("|") and word not in objs | _EV_GENERIC:
        return "제외", "다른 대상"
    return st


# 전사본 전체 문장에서 완료 근거 후보를 모은다. 반환: [{spk, word, text, status, why}]
def _done_evidence(joined: str, objs=frozenset()):
    lines = []
    for l in joined.split("\n"):
        m = re.match(r"^(\d+):\s?(.*)$", l)
        lines.append((m.group(1), m.group(2)) if m else (None, l))
    out = []
    for i, (spk, text) in enumerate(lines):
        later = " ".join(t for _, t in lines[i + 1:])
        for sent in re.split(r"(?<=[.?!])\s+", text):
            for m in _EV_MENTION.finditer(sent):
                st, why = _ev_judge(sent, m, later, objs)
                if st:
                    out.append({"spk": spk, "word": m.group().strip(), "text": sent.strip()[:100],
                                "status": st, "why": why})
    return out


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
        info["claims"] = claims
        ev = _done_evidence(joined, _claim_objects(parts["결과"]))
        info["evidence"] = ev[:8]
        if not any(e["status"] == "인정" for e in ev):
            if not any(e["status"] == "보류" for e in ev):
                return "", "overclaim", info
            info["overclaim"] = "unresolved"
    return summary, None, info
