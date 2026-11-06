"""별빛 프리즘: the scoring engine behind 별 띄우기.

Ported from Protoss `psy-punch-machine` (design.md). The punch score (0–999) is
the star's 별빛, and its three measures are the 06 lenses:
파고든 깊이 → 별의 깊이, 감정 명중률 → 빛의 선명함, 내 몫 인정 → 마음의 무게.
"""

from .engine import PrismEngine, PrismResult

__all__ = ["PrismEngine", "PrismResult"]
