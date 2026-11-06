"""Server-side checks before anything reaches the plaza.

Masking follows the iOS PrivacyScan (20 공유 전 확인); the server runs it again
so nothing unmasked is published even if the app's pass was skipped."""

import re

MASK = "●●●"

_PATTERNS = [
    # Phone numbers and email addresses
    # (digit lookarounds, not \b: Hangul counts as a word character, so "5678로" has no \b)
    ("contacts", r"(?<!\d)0\d{1,2}[-. ]?\d{3,4}[-. ]?\d{4}(?!\d)|[\w.+-]+@[\w-]+\.[A-Za-z.]+"),
    # A Korean name followed by a title or honorific (민지 씨, 지훈이 형)
    ("names", r"[가-힣]{2,3}(?=\s?(?:씨|님|선배|후배|언니|오빠|누나|형|선생님)(?:이랑|에게|한테|[이가은는을를랑과와도의께])?(?![가-힣]))"),
    # Place names by their suffix (강남역, 망원시장, 연남동 카페), also with a particle (강남역에서)
    ("places", r"[가-힣]{2,8}(?:역|구청|공원|학교|대학교|병원|카페|시장|해변|터미널)"
               r"(?=(?:에서|에|으로|로|은|는|이|가|을|를|과|와|의|도)?(?![가-힣]))"),
]


def scan(text: str) -> dict:
    """{"masked": …, "counts": {"names", "contacts", "places"}}"""
    counts = {}
    for kind, pattern in _PATTERNS:
        text, counts[kind] = re.subn(pattern, MASK, text)
    return {"masked": text, "counts": counts, "total": sum(counts.values())}


# 99 상처가 될 수 있는 말: iOS LineFilter words plus Protoss profanity.
_HURTFUL = ("죽어", "꺼져", "병신", "멍청", "한심", "쓰레기", "닥쳐", "유치", "시발", "씨발", "개새끼",
            "stupid", "idiot", "loser")


def is_hurtful(text: str) -> bool:
    lowered = text.lower()
    return any(w in lowered for w in _HURTFUL)
