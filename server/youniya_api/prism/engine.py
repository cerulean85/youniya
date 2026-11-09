"""별빛 프리즘 pipeline (Protoss design.md 1장):
pre-validation → safety interlock → N independent scoring calls → median → formula."""

import logging
import math
import re
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass

from ..llm import generate_json
from ..rules import MIN_FLOAT_LENGTH
from .calculator import final_scores
from .filters import foul_reason, has_crisis_signal
import contextvars

from .prompt import PREFIX, READING_PROMPT, reading_part, user_part
from .schemas import MoodShare, PrismSample

log = logging.getLogger(__name__)


@dataclass
class PrismResult:
    status: str  # ok | too_short | foul | crisis | failed
    message: str | None = None
    analysis: dict | None = None


def split_sentences(text: str) -> list[str]:
    return [s.strip() for s in re.findall(r"[^.!?\n]+[.!?]?", text) if len(s.strip()) > 1]


class PrismEngine:
    def __init__(self, api_key: str | None, model: str, samples: int = 3, thinking: str | None = None):
        self.api_key, self.model, self.sample_count, self.thinking = api_key, model, samples, thinking
        # A median needs at least two readings; one lost call out of three still gives a score.
        self.min_samples = min(2, samples)
        self.caches = None  # an ai_cache.CacheManager, set by the app

    def evaluate(self, title: str, body: str, min_length: int = MIN_FLOAT_LENGTH) -> PrismResult:
        foul = foul_reason(body, min_length)
        if foul:
            return PrismResult(status=foul[0], message=foul[1])
        if has_crisis_signal(f"{title}\n{body}"):
            return PrismResult(status="crisis")
        try:
            samples = self._samples(title, body)
        except Exception:
            # 36 별을 읽지 못했어요: the writing is kept and nothing is charged.
            return PrismResult(status="failed", message="별을 읽지 못했어요.")
        analysis = to_analysis(samples, body)
        if self.api_key:
            analysis |= self._reading(title, body, analysis)
        return PrismResult(status="ok", analysis=analysis)

    def _reading(self, title: str, body: str, analysis: dict) -> dict:
        """17.3 별빛 풀이 from the settled scores. A lost call leaves the reasons out (the app hides them),
        never the star: the depth reason falls back to the level evidence."""
        try:
            out = generate_json(self.api_key, self.model, reading_part(title, body, analysis["scores"],
                                                                        analysis["level_evidence"]),
                                prefix=READING_PROMPT + "\n\n", temperature=0.3, thinking=self.thinking,
                                timeout=25.0, retries=1)
        except Exception as e:  # noqa: BLE001
            log.warning("prism reading failed: %s", type(e).__name__)
            return {}
        keys = ("depth_reason", "clarity_reason", "weight_reason", "interpretation")
        got = {k: out[k].strip() for k in keys if isinstance(out.get(k), str) and out[k].strip()}
        return got | ({} if got.get("depth_reason") else {"depth_reason": analysis["level_evidence"]})

    def _samples(self, title: str, body: str) -> list[PrismSample]:
        if not self.api_key:
            return [mock_sample(title, body)] * self.sample_count
        prompt = user_part(title, body)
        cache = self.caches.for_request("prism", self.model, PREFIX) if self.caches else None
        # Each reading runs in a copy of this context, so the request's cost meter sees it.
        contexts = [contextvars.copy_context() for _ in range(self.sample_count)]
        with ThreadPoolExecutor(max_workers=self.sample_count) as pool:
            got = list(pool.map(lambda ctx: ctx.run(self._one, prompt, cache), contexts))
        samples = [s for s in got if s is not None]
        if len(samples) < self.min_samples:
            raise RuntimeError(f"only {len(samples)} of {self.sample_count} readings")
        return samples

    def _one(self, prompt: str, cache: str | None = None) -> PrismSample | None:
        """One independent reading, or None when the call or its JSON fails."""
        try:
            # With one reading there is no second to fall back on: a slow or dropped call is tried again
            # (one took 60 s in the 20261107 experiment). With three, a lost one is simply left out.
            single = self.sample_count == 1
            return PrismSample.model_validate(generate_json(
                self.api_key, self.model, prompt, thinking=self.thinking, prefix=PREFIX, cache=cache,
                timeout=25.0 if single else 60.0, retries=1 if single else 0))
        except Exception as e:  # noqa: BLE001 — any lost reading is just one fewer sample
            # Only where it failed: a validation message would quote the reading, and so the writing.
            where = [".".join(map(str, err["loc"])) for err in e.errors()] if hasattr(e, "errors") else []
            log.warning("prism reading failed: %s %s", type(e).__name__, where)
            return None


def to_analysis(samples: list[PrismSample], body: str) -> dict:
    scores = final_scores(samples)
    # The sample closest to the medians tells the story (Protoss engine step 5).
    best = min(
        samples,
        key=lambda s: abs(s.confrontation_depth - scores.confrontation_depth)
        + abs(s.naming_precision - scores.naming_precision)
        + abs(s.ownership - scores.ownership),
    )
    # Quotes must be the writer's own words, unchanged.
    signals = [s.strip() for s in best.signal_sentences if s.strip() and s.strip() in body]
    quote = best.impact_quote.strip()
    if not quote or quote not in body:
        quote = signals[0] if signals else (split_sentences(body) or [body])[0]

    total = sum(m.share for m in best.moods) or 1
    moods = [{"mood": m.mood, "share": round(m.share * 100 / total)} for m in best.moods]
    clarity = scores.naming_precision / 300
    return {
        "starlight": scores.total_score,
        "tier": scores.tier.value,
        "depth": round(scores.confrontation_depth / 400, 3),
        "clarity": round(clarity, 3),
        "weight": round(scores.ownership / 300, 3),
        "scores": {
            "depth": scores.confrontation_depth,
            "clarity": scores.naming_precision,
            "weight": scores.ownership,
        },
        "depth_level": best.experiencing_level,
        "level_evidence": best.level_evidence,
        "moods": moods,
        "observation": best.observation,
        "telescope_teaser": best.telescope_teaser,
        "rewrite_question": best.rewrite_question,
        "impact_quote": quote,
        "verdict": best.one_line_verdict,
        "tags": best.psych_tags,
        "signal_sentences": signals,
        "latent_hypothesis": best.latent_hypothesis,
        # 17.3 별빛 풀이: why each score, and the three read together.
        "depth_reason": best.depth_reason or best.level_evidence,
        "clarity_reason": best.clarity_reason,
        "weight_reason": best.weight_reason,
        "interpretation": best.interpretation,
        "self_attack": best.self_attack,
        # 76 "모양: 꼭짓점 5개 · 보통 뾰족함": deeper stars have more tips, clearer ones sharper.
        "shape": {
            "points": 3 + math.ceil(best.experiencing_level / 2),
            "sharpness": "soft" if clarity < 0.4 else "normal" if clarity < 0.7 else "sharp",
        },
    }


# --- Offline evaluator (no API key): deterministic cues, Protoss _mock_evaluate style ---

_MOOD_CUES = {
    "calm": ("평온", "괜찮", "고요", "쉬고", "쉬어", "느리", "편안", "안도", "차분"),
    "sorrow": ("슬프", "슬픔", "눈물", "서운", "외로", "그립", "아프", "울었"),
    "anger": ("화가", "화나", "짜증", "억울", "분노", "답답", "미웠"),
    "insight": ("깨달", "알게", "알았", "정리해 보면", "이제 보니", "원했던 건", "원하는 건"),
}
_FEELING = ("마음", "기분", "느낌", "느껴", "속이", "무서", "두려", "불안") + sum(_MOOD_CUES.values(), ())
_SELF_ATTACK = ("찌질", "못나", "쓰레기", "한심", "바보")
_QUESTION = ("왜", "어째서", "이유가", "까?")
_OBSERVATIONS = {
    "calm": "그런 마음이 머물렀군요.\n오늘의 별은 조용히 숨을 고르고 있어요.",
    "sorrow": "그 마음을 꺼내어 주었군요.\n오늘의 별은 천천히 젖은 빛을 말리고 있어요.",
    "anger": "뜨거운 마음이 지나갔군요.\n오늘의 별은 붉은 숨을 가라앉히고 있어요.",
    "insight": "무언가를 알아차렸군요.\n오늘의 별은 맑은 빛으로 반짝이고 있어요.",
}


def mock_sample(title: str, body: str) -> PrismSample:
    sentences = split_sentences(body) or [body.strip()]
    has = lambda words: any(w in body for w in words)  # noqa: E731
    insight, question = has(_MOOD_CUES["insight"]), has(_QUESTION)
    feeling, self_attack = has(_FEELING), has(_SELF_ATTACK)

    level = 7 if insight and "기준" in body else 6 if insight else 5 if question and feeling else 4 if feeling else 2
    # (depth, naming, ownership) per level, from the Protoss anchor examples.
    depth, naming, ownership = {2: (60, 50, 70), 4: (205, 170, 160), 5: (300, 250, 160),
                                6: (360, 280, 200), 7: (385, 285, 285)}[level]
    if self_attack:
        ownership = min(ownership, 120)

    counts = {m: sum(body.count(w) for w in cues) for m, cues in _MOOD_CUES.items()}
    ranked = [m for m, c in sorted(counts.items(), key=lambda kv: -kv[1]) if c > 0][:3] or ["calm"]
    total = sum(counts[m] for m in ranked) or 1
    moods = [MoodShare(mood=m, share=max(1, round(counts[m] * 100 / total))) for m in ranked]

    signals = [s for s in sentences if any(w in s for w in _FEELING)][:5]
    quote = max(signals or sentences, key=len)
    return PrismSample(
        confrontation_depth=depth,
        naming_precision=naming,
        ownership=ownership,
        experiencing_level=level,
        level_evidence=quote,
        surface_narrative=title or sentences[0],
        latent_hypothesis="없음",
        self_attack=self_attack,
        self_attack_spans=[s for s in sentences if any(w in s for w in _SELF_ATTACK)],
        impact_quote=quote,
        one_line_verdict="느낌을 피하지 않고 그 이유를 찾아 들어감" if level >= 5 else "일어난 일을 중심으로 서술함",
        psych_tags=["#" + m for m in ranked],
        moods=moods,
        observation=_OBSERVATIONS[ranked[0]],
        telescope_teaser="말하지 않은 마음이 한 겹 더 있을지도 몰라요.",
        rewrite_question="그 마음은 어디에서 오고 있었을까요?",
        signal_sentences=signals,
        depth_reason=f"{'속마음까지 내려가' if level >= 5 else '일어난 일을 따라가며'} 마주한 깊이가 {depth}점이에요.",
        clarity_reason=f"마음에 이름을 붙인 선명함이 {naming}점이에요.",
        weight_reason=f"마음을 내 것으로 품어낸 무게가 {ownership}점이에요.",
        interpretation=_OBSERVATIONS[ranked[0]].split("\n")[0] + " 세 빛이 함께 이 별의 모양을 이뤄요.",
    )
