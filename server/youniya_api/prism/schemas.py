from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field, field_validator

Mood = Literal["calm", "sorrow", "anger", "insight"]


class Tier(str, Enum):
    """Protoss design.md 2.6. 900+ is a 초신성 (90)."""

    SHADOW_SWING = "SHADOW_SWING"  # 0~399
    GUARDED = "GUARDED"  # 400~699
    HEAVY_BLOW = "HEAVY_BLOW"  # 700~899
    CRITICAL_HIT = "CRITICAL_HIT"  # 900~999


class MoodShare(BaseModel):
    mood: Mood
    share: int = Field(..., ge=0, le=100)


class PrismSample(BaseModel):
    """One independent scoring call. The first block is Protoss LLMSampleOutput as is."""

    confrontation_depth: int = Field(..., ge=0, le=400)
    naming_precision: int = Field(..., ge=0, le=300)
    ownership: int = Field(..., ge=0, le=300)
    experiencing_level: int = Field(..., ge=1, le=7)
    level_evidence: str
    surface_narrative: str
    latent_hypothesis: str = "없음"
    self_attack: bool = False
    self_attack_spans: list[str] = Field(default_factory=list)
    impact_quote: str
    one_line_verdict: str
    psych_tags: list[str] = Field(default_factory=list)

    # YOUNIYA screens
    moods: list[MoodShare] = Field(..., min_length=1, max_length=3)  # 07 감정 칩, 10 감정의 결
    observation: str  # 07 "그런 마음이 머물렀군요. …"
    telescope_teaser: str = "망원경으로 보면 이 별의 결이 조금 더 또렷해져요."  # 07 마음 망원경 카드의 한 줄
    rewrite_question: str  # 14 다시 쓰기 질문
    signal_sentences: list[str] = Field(default_factory=list, max_length=5)  # 88 불이 켜진 문장

    @field_validator("latent_hypothesis", "telescope_teaser", mode="before")
    @classmethod
    def _null_is_unset(cls, v, info):
        """The model sometimes sends null when it has nothing to say: use the default line."""
        return cls.model_fields[info.field_name].default if v is None else v


class Scores(BaseModel):
    confrontation_depth: int
    naming_precision: int
    ownership: int
    total_score: int = Field(..., ge=0, le=999)
    tier: Tier
