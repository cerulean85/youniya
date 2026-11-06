"""Product rules from the Figma screens and the iOS app (AppModel.swift)."""

MOODS = ("calm", "sorrow", "anger", "insight")  # 평온 · 슬픔 · 분노 · 통찰
MOOD_LABELS = {"calm": "평온", "sorrow": "슬픔", "anger": "분노", "insight": "통찰"}

# 104/105: floating (analysis) needs 1,000 characters; keeping has no minimum.
MIN_FLOAT_LENGTH = 1000

# 24 마음 망원경: 30 coins, the first one free (07 "처음 한 번은 무료").
TELESCOPE_COST = 30
# 83 서사 다듬기 · 코인 20
STORY_POLISH_COST = 20

# 28 코인 충전. Prices in KRW.
COIN_PACKAGES = {
    "coin_50": {"coins": 50, "price": 3300},
    "coin_120": {"coins": 120, "price": 6600},
    "coin_300": {"coins": 300, "price": 14900},
}

# 90 초신성: starlight over 900 (Protoss CRITICAL_HIT).
SUPERNOVA_STARLIGHT = 900
# A "깊은 별": depth score ≥ 0.7 of 400 (iOS StarAnalysis.isDeep).
DEEP_DEPTH_SCORE = 280

# 86 성운이 자라는 네 걸음
STAGE_NAMES = ("첫 별들", "따뜻한 빛줄기", "짙어지는 성운", "온전한 은하수")

# 96 "별이 3개 이상 모이면 성운을 그릴 수 있어요", 85 guest stars up to 5.
MIN_NEBULA_STARS = 3
MAX_GUEST_STARS = 5
NEBULA_SILHOUETTES = ("whale", "lighthouse", "tree", "bird", "flower")

# 74 별빛 한 줄: one line per nebula per person, 60 characters, fades after a day.
LINE_MAX_LENGTH = 60
LINE_LIFETIME_HOURS = 24
LINE_REPORT_REASONS = ("hurtful", "personal_info", "spam", "other")

SKY_THEMES = ("violet", "aurora", "ember", "ocean", "rose")
SOUNDS = ("밤바람", "미세한 성간 주파수")
INQUIRY_KINDS = ("payment", "account", "other")  # 결제 · 계정 · 기타


def growth_stage(deep: int, brightest: int, moods: int) -> int:
    """86: 1 첫 별들 · 2 깊은 별 6 · 3 깊은 별 15와 별빛 900 이상 1번 · 4 깊은 별 30과 여러 감정의 결."""
    if deep >= 30 and moods >= 3:
        return 4
    if deep >= 15 and brightest >= SUPERNOVA_STARLIGHT:
        return 3
    if deep >= 6:
        return 2
    return 1
