"""Pre-validation and the safety interlock (Protoss psy_punch.filters, design.md 5)."""

import re

# Protoss CRISIS_PATTERNS together with the iOS CrisisSignal phrases.
CRISIS_PATTERNS = [
    r"자해", r"자살", r"죽고\s*싶", r"살기\s*싫", r"살고\s*싶지\s*않", r"목숨을\s*끊", r"극단적\s*선택",
    r"사라지고\s*싶", r"없어지고\s*싶", r"세상을\s*떠나", r"죽어버리", r"스스로\s*목숨", r"삶을\s*끝",
    r"끝내고\s*싶", r"뛰어내리",
    r"suicide", r"kill myself", r"want to die", r"end my life", r"self[- ]harm",
]

# 37 위기 돌봄
CRISIS_GUIDANCE = {
    "title": "지금 많이 힘드신가요?",
    "message": "혼자 견디지 않아도 괜찮아요.\n전문 상담이 24시간 열려 있어요.",
    "contacts": [
        {"name": "자살예방 상담전화", "phone": "109", "hours": "24시간"},
        {"name": "정신건강 상담전화", "phone": "1577-0199", "hours": "24시간"},
    ],
}

_PROFANITY_ONLY = re.compile(r"^(ㅅㅂ|시발|씨발|존나|병신|개새끼|\s)+$")
_REPEAT = re.compile(r"([ㄱ-ㅎㅏ-ㅣa-zA-Z!?.~])\1{4,}")


def has_crisis_signal(text: str) -> bool:
    lowered = text.lower()
    return any(re.search(p, lowered) for p in CRISIS_PATTERNS)


def foul_reason(text: str, min_length: int) -> tuple[str, str] | None:
    """(code, message) when the text can't be scored, else None."""
    stripped = text.strip()
    if len(stripped) < min_length:
        return "too_short", f"{min_length:,}자부터 별로 띄울 수 있어요."
    m = _REPEAT.search(stripped)
    if m and len(stripped.replace(m.group(0), "").strip()) < 20:
        return "foul", "같은 글자만 이어진 글은 별로 띄울 수 없어요."
    if _PROFANITY_ONLY.match(stripped):
        return "foul", "욕설만으로는 별을 띄울 수 없어요."
    return None
