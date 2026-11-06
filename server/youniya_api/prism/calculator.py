"""Deterministic scoring (Protoss psy_punch.calculator, design.md 2.3)."""

import statistics

from .schemas import PrismSample, Scores, Tier


def tier_for(total: int) -> Tier:
    if total >= 900:
        return Tier.CRITICAL_HIT
    if total >= 700:
        return Tier.HEAVY_BLOW
    if total >= 400:
        return Tier.GUARDED
    return Tier.SHADOW_SWING


def final_scores(samples: list[PrismSample]) -> Scores:
    """Median of each measure across samples, then S = min(999, D + N + O)."""
    if not samples:
        raise ValueError("at least one sample is required")
    d = int(statistics.median(s.confrontation_depth for s in samples))
    n = int(statistics.median(s.naming_precision for s in samples))
    o = int(statistics.median(s.ownership for s in samples))
    total = min(999, d + n + o)
    return Scores(confrontation_depth=d, naming_precision=n, ownership=o, total_score=total, tier=tier_for(total))
