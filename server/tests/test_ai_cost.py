"""Per-account AI cost and explicit context caches."""

from datetime import date

from youniya_api import ai_cost
from youniya_api.ai_cache import CACHE_FROM_PER_HOUR, CacheManager
from youniya_api.models import AdminLog, AiCost

from .conftest import sign_in


def test_cost_from_usage_with_cached_tokens():
    usage = {"promptTokenCount": 3000, "cachedContentTokenCount": 2000, "candidatesTokenCount": 600}
    # 1,000 fresh × 0.75 + 2,000 cached × 0.075 + 600 × 3.75 = 3,150 µ$ → 4.725 KRW
    assert round(ai_cost.krw("gemini-3.8-flash", usage, date(2026, 11, 7)), 3) == 4.725
    assert round(ai_cost.krw("gemini-3.8-flash", usage, date(2027, 1, 1)), 3) == 9.45


def test_month_cost_is_kept_and_the_operator_hears_once(make_app, caplog):
    app = make_app()
    from fastapi.testclient import TestClient

    client = TestClient(app)
    h = sign_in(client)
    user_id = client.get("/v1/me", headers=h).json()["id"]
    big = ("gemini-3.8-flash", {"promptTokenCount": 1_000_000, "candidatesTokenCount": 200_000})  # 2,250 KRW
    with app.state.sessions() as db:
        ai_cost.record(db, user_id, [big])
        ai_cost.record(db, user_id, [big])
        row = db.get(AiCost, (user_id, ai_cost.this_month()))
        assert row.calls == 2 and round(row.krw) == 4500 and row.alerted
        assert db.query(AdminLog).filter_by(action="ai_cost_over").count() == 1
    assert sum("AI cost for" in r.message for r in caplog.records) == 1


def test_cache_made_after_ten_an_hour_then_reused(make_app, monkeypatch):
    app = make_app()
    made = []

    class Answer:
        def __init__(self, status, body):
            self.status_code, self._body, self.text = status, body, str(body)

        def json(self):
            return self._body

        def raise_for_status(self):
            assert self.status_code == 200

    def post(url, **kw):
        made.append(kw["json"])
        too_small = len(kw["json"]["contents"][0]["parts"][0]["text"]) < 100
        return Answer(400, {"error": {"message": "Cached content is too small."}}) if too_small else \
            Answer(200, {"name": f"cachedContents/c{len(made)}"})

    monkeypatch.setattr("youniya_api.ai_cache.httpx.post", post)
    caches = CacheManager(app.state.sessions, "key")
    big, small = "규칙 " * 200, "짧은 규칙"
    names = [caches.for_request("prism", "gemini-3.8-flash", big) for _ in range(CACHE_FROM_PER_HOUR + 2)]
    assert names[:CACHE_FROM_PER_HOUR - 1] == [None] * (CACHE_FROM_PER_HOUR - 1)
    assert names[CACHE_FROM_PER_HOUR - 1:] == ["cachedContents/c1"] * 3 and len(made) == 1  # one cache, reused
    # A new prompt version makes a new cache.
    assert caches.for_request("prism", "gemini-3.8-flash", big + "v2") == "cachedContents/c2"
    # Too small: tried once, then left alone.
    for _ in range(CACHE_FROM_PER_HOUR + 3):
        assert caches.for_request("story", "gemini-3.8-flash", small) is None
    assert len(made) == 3
