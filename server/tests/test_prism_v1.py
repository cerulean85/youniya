"""17.3 별빛 풀이, 17.6 측정 방식 버전, 11.5 망원경 결과를 별에 (20261109). Offline evaluator."""

from youniya_api.rules import PRISM_VERSION

from .conftest import float_star, sign_in


def test_reading_has_reasons_and_a_version(client):
    h = sign_in(client)
    star = float_star(client, h)
    a = star["analysis"]
    assert star["prism_version"] == PRISM_VERSION
    assert all(a[k] for k in ("depth_reason", "clarity_reason", "weight_reason", "interpretation"))
    unlit = client.post("/v1/stars", json={"mood": "calm", "body": "글", "mode": "unlit"}, headers=h).json()["star"]
    assert unlit["prism_version"] is None


def test_telescope_result_sits_on_the_star(client):
    h = sign_in(client)
    star = float_star(client, h)
    assert client.get(f"/v1/stars/{star['id']}", headers=h).json()["telescope"] is None
    client.post("/v1/telescope/reports", json={"star_ids": [star["id"]]}, headers=h)
    t = client.get(f"/v1/stars/{star['id']}", headers=h).json()["telescope"]["report"]
    depth = next(lens for lens in t["lenses"] if lens["key"] == "depth")
    assert depth["score"] == star["analysis"]["scores"]["depth"] and depth["reason"] == star["analysis"]["depth_reason"]
    assert set(t["mood_flow"]) == {"start", "middle", "end"} and t["fog_items"] == []
    assert t["mood_interpretation"]


def test_a_lost_reading_is_counted_and_the_star_kept(client, monkeypatch):
    from youniya_api.models import AiUsage
    from youniya_api.prism import PrismEngine, engine
    from youniya_api.prism.prompt import READING_PROMPT

    from .conftest import DEEP_BODY

    def fake(api_key, model, prompt, prefix="", **kw):
        if prefix.startswith(READING_PROMPT[:20]):
            raise TimeoutError("reading")
        return engine.mock_sample("", DEEP_BODY).model_dump()

    monkeypatch.setattr(engine, "generate_json", fake)
    client.app.state.prism = PrismEngine("key", "gemini-3.8-flash", 1)
    h = sign_in(client)
    star = float_star(client, h)
    a = star["analysis"]
    assert star["starlight"] > 0 and star["has_starlight"] and a["depth_reason"]  # the star is lit all the same
    with client.app.state.sessions() as db:
        u = db.query(AiUsage).one()
        assert (u.feature, u.attempts, u.failures) == ("prism_reading", 1, 1)
