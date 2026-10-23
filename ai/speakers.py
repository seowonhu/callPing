import re, collections

# -----------------------------------------------------------
# 화자 처리
# -----------------------------------------------------------

_NUM = re.compile(r"^\d+$")


# 화자 라벨을 숫자로 맞춘다 (숫자가 아니면 나온 순서대로 1, 2, 3…)
def normalize_speakers(turns):
    if all(_NUM.match(str(t.speaker).strip()) for t in turns):
        return [(str(t.speaker).strip(), t.text) for t in turns]
    mapping, out = {}, []
    for t in turns:
        k = str(t.speaker).strip()
        if k not in mapping:
            mapping[k] = str(len(mapping) + 1)
        out.append((mapping[k], t.text))
    return out


# 화자 · 턴 수 기록
def _note_transcript(st, turns, raw):
    try:
        best = cur = 0
        prev = None
        for spk, _ in turns:
            cur = cur + 1 if spk == prev else 1
            prev = spk
            best = max(best, cur)
        st["turns"] = len(turns)
        st["speakers"] = dict(collections.Counter(spk for spk, _ in turns))
        st["max_run"] = best
        rawlab = [str(t.speaker).strip() for t in raw]
        if any(not _NUM.match(x) for x in rawlab):
            st["speakers_raw"] = list(dict.fromkeys(rawlab))[:10]
    except Exception:
        pass
