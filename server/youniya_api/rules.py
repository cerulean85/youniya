"""Product rules from the Figma screens and the iOS app (AppModel.swift)."""

MOODS = ("calm", "sorrow", "anger", "insight")  # 평온 · 슬픔 · 분노 · 통찰
MOOD_LABELS = {"calm": "평온", "sorrow": "슬픔", "anger": "분노", "insight": "통찰"}

# 104/105: floating (analysis) needs 50 characters (1,000 until 20261108); keeping has no minimum.
MIN_FLOAT_LENGTH = 50

# Prices (기획 확정 20261107, 1 coin = 10 KRW). Free uses: youniya_api/allowance.py.
STAR_FLOAT_COST = 5  # 별 띄우기 after the day's free one
TELESCOPE_COST = 20  # 24 마음 망원경

# 28 코인 충전. Prices in KRW. `sold: False` packages are no longer offered, but purchases and
# refunds of them are still recognised.
COIN_PACKAGES = {
    "coin_110": {"coins": 110, "price": 1100, "sold": True},
    "coin_330": {"coins": 330, "price": 3300, "sold": True},
    "coin_1100": {"coins": 1100, "price": 9900, "sold": True, "bonus": 100},
    "coin_50": {"coins": 50, "price": 3300, "sold": False},
    "coin_120": {"coins": 120, "price": 6600, "sold": False},
    "coin_300": {"coins": 300, "price": 14900, "sold": False},
}

# 46 결제·환불 정책: unspent coins can be refunded within 7 days of purchase; spent coins can't.
REFUND_WINDOW_DAYS = 7

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
# 기획서 13.5 계절 팩: 별지기 멤버십 silhouettes. A nebula saved with one keeps it after the membership ends.
MEMBER_SILHOUETTES = ("cherry_blossom", "wave", "maple", "snowflake")

# 74 별빛 한 줄: one line per nebula per person, 60 characters, fades after a day.
LINE_MAX_LENGTH = 60
LINE_LIFETIME_HOURS = 24
LINE_REPORT_REASONS = ("hurtful", "personal_info", "spam", "other")

SKY_THEMES = ("violet", "aurora", "ember", "ocean", "rose")
# 기획서 13장: violet and ocean for everyone; the rest are 별지기 멤버십 skies (from v1.0 on).
FREE_SKIES = ("violet", "ocean")

# 별지기 멤버십 (v1.1, behind MEMBERSHIP=1). One auto-renewable subscription group, 7-day free trial.
MEMBERSHIP_PRODUCTS = {"membership_monthly": 2900, "membership_yearly": 29000}  # KRW
MEMBER_DAILY_LIMIT = 10  # each of floats and telescope reports, a Korean day; then coins
MONTHLY_REPORT_MIN_STARS = 5  # stars floated in the month
AI_COST_ALERT_KRW = 2000  # a month's model cost for one account above this is logged for the operator
SOUNDS = ("밤바람", "미세한 성간 주파수")
INQUIRY_KINDS = ("payment", "account", "other")  # 결제 · 계정 · 기타


FIRST_STAGE_STARS = 12  # 기획서 5.1: 별 12개부터 첫 단계


def growth_stage(total: int, deep: int, brightest: int, moods: int) -> int:
    """86: 0 첫 단계 전 · 1 첫 별들(별 12개) · 2 깊은 별 6 · 3 깊은 별 15와 별빛 900 이상 1번 ·
    4 깊은 별 30과 여러 감정의 결. Stages go in order: every stage needs the 12 stars first.
    `total` counts every star, floated or kept."""
    if total < FIRST_STAGE_STARS:
        return 0
    if deep >= 30 and moods >= 3:
        return 4
    if deep >= 15 and brightest >= SUPERNOVA_STARLIGHT:
        return 3
    if deep >= 6:
        return 2
    return 1
