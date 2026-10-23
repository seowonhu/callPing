import re

# -----------------------------------------------------------
# 피드백 · 가이드 출력 정리
# -----------------------------------------------------------

SEC_E, SEC_F = "[표현 분석]", "[개선 피드백]"


# 피드백 출력을 [표현 분석] / [개선 피드백] 으로 나눔
def split_sections(text: str):
    if SEC_E in text and SEC_F in text:
        i, j = text.index(SEC_E), text.index(SEC_F)
        if i < j:
            expression = text[i + len(SEC_E):j].strip()
            feedback = text[j + len(SEC_F):].strip()
            if expression or feedback:
                return (expression or None), feedback
    return None, text.strip()

_GUIDE_HDR = re.compile(r'^(말투|이렇게 말해보세요|챙길 것|주의)\s*[:：]\s*(.*)$')


# 가이드 구조를 대본 / 도움말로 나눔
def split_guide(text: str):
    sections, cur = {}, None
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        m = _GUIDE_HDR.match(s)
        if m:
            cur = m.group(1)
            rest = m.group(2).strip()
            sections[cur] = [rest] if rest else []
        elif cur:
            sections[cur].append(s.lstrip('-•· ').strip())

    script = sections.get("이렇게 말해보세요", [])
    if not script:
        return text.strip(), []

    tips = []
    if sections.get("말투"):
        tips.append("말투: " + " ".join(sections["말투"]))
    if sections.get("챙길 것"):
        tips.append("챙길 것: " + ", ".join(sections["챙길 것"]))
    if sections.get("주의"):
        tips.append("주의: " + " ".join(sections["주의"]))
    return "\n".join(script), tips


def render_guide(text: str):
    script, tips = split_guide(text)
    out = "[대본]\n" + script
    if tips:
        out += "\n\n[도움말]\n" + "\n".join("• " + t for t in tips)
    return out, script, tips

def split_feedback(expression, feedback):
    advice, improves = [], []
    for line in (feedback or "").splitlines():
        s = line.strip()
        if not s:
            continue
        (improves if "추천 표현" in s else advice).append(s)
    return {
        "tone_analysis": (expression or "").strip(),
        "speech_feedback": " ".join(advice),
        "improvement_points": "\n".join(improves),
    }

# -----------------------------------------------------------
# 할 일 파싱
# -----------------------------------------------------------

# 출력 형식: [높음] 할 일 | 근거: "전사본 문장"  또는  없음
_PRIORITY = {"높음": "HIGH", "보통": "MEDIUM", "낮음": "LOW"}
_TODO_RE = re.compile(r"^\s*(?:[-*•]\s*)?\[?\s*(높음|보통|낮음)\s*\]?\s*[:：]?\s*(.+?)\s*$")
_NONE_RE = re.compile(r"^\s*(?:[-*•]\s*)?(?:없음|없습니다|해당\s*없음|후속\s*조치\s*없음)\s*[.]?\s*$")
_BASIS_RE = re.compile(r"^(.*?)\s*[|\-–]\s*근거\s*[:：]?\s*[\"“'‘]?(.+?)[\"”'’]?\s*$")
MAX_TODOS = 3
_STRIP = "\"“”'‘’.。!?！？~…, "


def _norm(s: str) -> str:
    return re.sub(r"\s+", "", (s or "").strip(_STRIP))


# 근거 문장이 전사본에 없으면 버린다
def _parse_todos_detail(text: str, transcript_text: str = ""):
    hay = _norm(re.sub(r"(?m)^\s*\d+\s*:\s*", "", transcript_text or ""))
    todos, unparsed, dropped, seen = [], [], [], set()
    for line in (text or "").splitlines():
        s = line.strip()
        if not s:
            continue
        if _NONE_RE.match(s):
            break
        m = _TODO_RE.match(s)
        if not m:
            unparsed.append(s)
            continue
        b = _BASIS_RE.match(m.group(2).strip())
        if not b:
            dropped.append({"line": s, "why": "근거 없음"})
            continue
        desc, quote = b.group(1).strip(_STRIP), b.group(2).strip()
        if not desc or not quote:
            dropped.append({"line": s, "why": "할 일 또는 인용 비어 있음"})
            continue
        if hay and _norm(quote) not in hay:
            dropped.append({"line": s, "why": "인용이 전사본에 없음"})
            continue
        key = _norm(desc)
        if key in seen:
            dropped.append({"line": s, "why": "중복"})
            continue
        seen.add(key)
        todos.append({"task_type": "OTHER",
                      "description": desc,
                      "priority": _PRIORITY[m.group(1)],
                      "status": "PENDING",
                      "evidence": quote})
    return todos[:MAX_TODOS], unparsed, dropped


_PUBLIC = ("task_type", "description", "priority", "status")


# 응답에 나가는 필드만
def public_todo(td: dict) -> dict:
    return {k: td[k] for k in _PUBLIC}


def parse_todos(text: str, transcript_text: str):
    return [public_todo(td) for td in _parse_todos_detail(text, transcript_text)[0]]


def todo_summary(n: int) -> str:
    return f"총 {n}건의 후속 조치가 필요합니다."
