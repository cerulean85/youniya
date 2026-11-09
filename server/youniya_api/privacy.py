"""Server-side checks before anything reaches the plaza.

Masking follows the iOS PrivacyScan (20 공유 전 확인); the server runs it again
so nothing unmasked is published even if the app's pass was skipped."""

import re

MASK = "●●●"

_PATTERNS = [
    # Phone numbers and email addresses
    # (digit lookarounds, not \b: Hangul counts as a word character, so "5678로" has no \b)
    ("contacts", r"(?<!\d)0\d{1,2}[-. ]?\d{3,4}[-. ]?\d{4}(?!\d)|[\w.+-]+@[\w-]+\.[A-Za-z.]+"),
    # Identifying numbers, counted with contacts: 주민등록번호, card and account numbers
    # (three or four groups of digits, 10 or more in all, so a date like 2026-11-08 stays; or 10–16 in a row).
    ("contacts", r"(?<!\d)\d{6}[- ]?[1-8]\d{6}(?!\d)|(?<!\d)(?=(?:\d[- ]?){10,})\d{2,6}(?:[- ]\d{2,6}){2,3}(?!\d)|(?<!\d)\d{10,16}(?!\d)"),
    # A Korean name followed by a title or honorific (민지 씨, 지훈이 형)
    ("names", r"[가-힣]{2,3}(?=\s?(?:씨|님|선배|후배|언니|오빠|누나|형|선생님)(?:이랑|에게|한테|[이가은는을를랑과와도의께])?(?![가-힣]))"),
    # Place names by their suffix (강남역, 망원시장, 연남동 카페), also with a particle (강남역에서)
    ("places", r"[가-힣]{2,8}(?:역|구청|공원|학교|대학교|병원|카페|시장|해변|터미널)"
               r"(?=(?:에서|에|으로|로|은|는|이|가|을|를|과|와|의|도)?(?![가-힣]))"),
]


def scan(text: str, mode: str = "all") -> dict:
    """{"masked": …, "counts": {"names", "contacts", "places"}}. mode "all" masks names and places
    too (a single sentence, a nebula); "contacts" only contacts and identifying numbers (a star's
    whole writing on the plaza, 20261108: names and places stay as written)."""
    counts = {"contacts": 0, "names": 0, "places": 0}
    for kind, pattern in _PATTERNS:
        if mode == "contacts" and kind != "contacts":
            continue
        text, n = re.subn(pattern, MASK, text)
        counts[kind] += n
    return {"masked": text, "counts": counts, "total": sum(counts.values())}


# 99 상처가 될 수 있는 말: iOS LineFilter words plus Protoss profanity.
_HURTFUL = ("죽어", "꺼져", "병신", "멍청", "한심", "쓰레기", "닥쳐", "유치", "시발", "씨발", "개새끼",
            "stupid", "idiot", "loser")


# 10.1 별빛 한 줄 is warmth, not a verdict or a prescription.
_JUDGING = ("네 잘못", "니 잘못", "당신 잘못", "이상해", "이상하다", "별로", "유난", "예민", "오버", "그럴 만해")
_ADVICE = ("해야 해", "해야해", "해야 돼", "해야돼", "하세요", "해 봐", "해봐", "하지 마", "하지마", "는 게 좋아",
           "는게 좋아", "는 게 나아", "병원 가", "상담 받아", "상담받아", "잊어버려", "잊어", "털어버려")


def line_problem(text: str) -> str | None:
    """None, or why a line cannot go: hurtful | contact | judging | advice."""
    low = text.lower()
    if is_hurtful(low):
        return "hurtful"
    if scan(text, "contacts")["total"]:
        return "contact"
    if any(w in low for w in _JUDGING):
        return "judging"
    if any(w in low for w in _ADVICE):
        return "advice"
    return None


def is_hurtful(text: str) -> bool:
    lowered = text.lower()
    return any(w in lowered for w in _HURTFUL)
