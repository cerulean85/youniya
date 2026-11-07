from youniya_api.prism import PrismEngine
from youniya_api.prism.calculator import final_scores, tier_for
from youniya_api.prism.engine import mock_sample, to_analysis
from youniya_api.prism.filters import foul_reason, has_crisis_signal
from youniya_api.prism.schemas import Tier

from .conftest import CALM_BODY, DEEP_BODY


def sample(d, n, o, **kw):
    s = mock_sample("t", DEEP_BODY)
    return s.model_copy(update={"confrontation_depth": d, "naming_precision": n, "ownership": o, **kw})


def test_median_and_cap():
    # Protoss design.md 2.3: medians per measure, then min(999, D + N + O)
    scores = final_scores([sample(385, 285, 285), sample(300, 200, 100), sample(390, 290, 290)])
    assert (scores.confrontation_depth, scores.naming_precision, scores.ownership) == (385, 285, 285)
    assert scores.total_score == 955
    assert scores.tier == Tier.CRITICAL_HIT
    assert final_scores([sample(400, 300, 300)]).total_score == 999


def test_tiers():
    assert tier_for(399) == Tier.SHADOW_SWING
    assert tier_for(400) == Tier.GUARDED
    assert tier_for(700) == Tier.HEAVY_BLOW
    assert tier_for(900) == Tier.CRITICAL_HIT


def test_float_needs_1000_characters():
    assert foul_reason("짧은 글", 1000)[0] == "too_short"
    assert foul_reason("ㅋ" * 1200, 1000)[0] == "foul"
    assert foul_reason(DEEP_BODY, 1000) is None


def test_crisis_signal():
    assert has_crisis_signal("요즘은 그냥 사라지고 싶다는 생각이 들어요")
    assert has_crisis_signal("I want to die")
    assert not has_crisis_signal(CALM_BODY)


def test_engine_result_shape():
    result = PrismEngine(api_key=None, model="m").evaluate("제목", DEEP_BODY)
    assert result.status == "ok"
    a = result.analysis
    assert 0 <= a["starlight"] <= 999
    assert a["depth_level"] == 7
    assert a["starlight"] >= 900 and a["tier"] == "CRITICAL_HIT"
    assert abs(sum(m["share"] for m in a["moods"]) - 100) <= 2
    # Quotes are always the writer's own sentences.
    assert a["impact_quote"] in DEEP_BODY
    assert all(s in DEEP_BODY for s in a["signal_sentences"])
    assert a["shape"] == {"points": 7, "sharpness": "sharp"}


def test_quote_not_in_text_is_replaced():
    s = mock_sample("t", CALM_BODY).model_copy(update={"impact_quote": "원문에 없는 문장", "signal_sentences": ["없는 문장"]})
    a = to_analysis([s], CALM_BODY)
    assert a["impact_quote"] in CALM_BODY
    assert a["signal_sentences"] == []


def test_model_failure_is_reported(monkeypatch):
    def boom(*a, **k):
        raise RuntimeError("down")

    monkeypatch.setattr("youniya_api.prism.engine.generate_json", boom)
    assert PrismEngine(api_key="k", model="m").evaluate("t", DEEP_BODY).status == "failed"


def test_one_lost_reading_still_scores(monkeypatch):
    """Two good readings of three give a score; one does not."""
    import itertools

    good = mock_sample("t", DEEP_BODY).model_dump()
    seen = []

    def calls(outcomes):
        it = itertools.cycle(outcomes)

        def fake(api_key, model, prompt, **kw):
            seen.append(kw)
            o = next(it)
            if o == "boom":
                raise TimeoutError("slow")
            return {"confrontation_depth": 999} if o == "bad" else good

        return fake

    monkeypatch.setattr("youniya_api.prism.engine.generate_json", calls(["ok", "boom", "ok"]))
    r = PrismEngine(api_key="k", model="m", thinking="low").evaluate("t", DEEP_BODY)
    assert r.status == "ok" and r.analysis["starlight"] == 955
    assert seen[0] == {"thinking": "low", "timeout": 60.0, "retries": 0}

    monkeypatch.setattr("youniya_api.prism.engine.generate_json", calls(["ok", "boom", "bad"]))
    assert PrismEngine(api_key="k", model="m").evaluate("t", DEEP_BODY).status == "failed"


def test_null_teaser_takes_the_default_line():
    from youniya_api.prism.schemas import PrismSample

    raw = mock_sample("t", DEEP_BODY).model_dump() | {"telescope_teaser": None, "latent_hypothesis": None}
    s = PrismSample.model_validate(raw)
    assert s.telescope_teaser.startswith("망원경으로") and s.latent_hypothesis == "없음"


def test_thinking_off_and_retries(monkeypatch):
    import httpx

    from youniya_api import llm

    assert llm.thinking_config("gemini-3.8-flash", "off") == {"thinkingBudget": 0}
    assert llm.thinking_config("gemini-3.5-flash-lite", "off") == {"thinkingLevel": "minimal"}
    assert llm.thinking_config("gemini-3.8-flash", "low") == {"thinkingLevel": "low"}
    assert llm.thinking_config("gemini-3.8-flash", None) is None

    tries = []

    def handler(request):
        tries.append(request)
        if len(tries) == 1:
            raise httpx.ReadTimeout("slow")
        return httpx.Response(200, json={"candidates": [{"content": {"parts": [{"text": '{"ok": 1}'}]}}]})

    real = httpx.Client
    monkeypatch.setattr(llm.httpx, "Client", lambda **kw: real(transport=httpx.MockTransport(handler), **kw))
    assert llm.generate_json("k", "m", "p", retries=1) == {"ok": 1} and len(tries) == 2
    tries.clear()
    import pytest

    with pytest.raises(httpx.ReadTimeout):
        llm.generate_json("k", "m", "p")  # no retry by default
