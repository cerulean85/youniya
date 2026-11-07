"""Prices and free uses (기획 확정 20261107): 1 coin = 10 KRW."""

from fastapi.testclient import TestClient

from youniya_api.prism.engine import PrismResult

from .conftest import CALM_BODY, DEEP_BODY, float_star, sign_in

STAR = {"mood": "insight", "title": "오늘", "body": DEEP_BODY, "mode": "float"}


def _client(make_app):
    return TestClient(make_app(free_stars_per_day=1))


def _me(client, h):
    me = client.get("/v1/me", headers=h).json()
    return me["free_star_today"], me["free_telescope"], me["free_story"], me["coins"]


def test_one_free_star_a_day_then_five_coins(make_app, monkeypatch):
    client = _client(make_app)
    h = sign_in(client)
    assert _me(client, h) == (1, 2, 1, 0)

    first = client.post("/v1/stars", json=STAR, headers=h).json()
    assert first["charged"] == 0 and first["star"]["state"] == "floated"
    assert _me(client, h)[0] == 0
    # Deleting today's star does not give the free one back.
    client.delete(f"/v1/stars/{first['star']['id']}", headers=h)
    assert _me(client, h)[0] == 0

    r = client.post("/v1/stars", json=STAR, headers=h)
    assert r.status_code == 402 and r.json()["error"] == {
        "code": "insufficient_coins", "message": "코인이 조금 부족해요.", "coins": 0, "cost": 5}
    assert client.get("/v1/stars", headers=h).json()["items"] == []  # nothing stored; the app keeps the draft

    # Keeping is always free, and so is a crisis star (it is never read).
    keep = client.post("/v1/stars", json=STAR | {"mode": "keep"}, headers=h).json()
    assert keep["charged"] == 0
    assert client.post("/v1/stars", json=STAR | {"body": CALM_BODY + " 죽고 싶다"}, headers=h).json()["charged"] == 0

    client.post("/v1/coins/purchases", json={"product_id": "coin_110", "transaction_id": "a"}, headers=h)
    paid = client.post("/v1/stars", json=STAR, headers=h).json()
    assert paid["charged"] == 5 and paid["coins"] == 105
    assert client.post(f"/v1/stars/{keep['star']['id']}/float", headers=h).json()["charged"] == 5

    # A star the prism could not read charges nothing.
    monkeypatch.setattr(client.app.state.prism, "evaluate", lambda t, b: PrismResult(status="failed"))
    failed = client.post("/v1/stars", json=STAR, headers=h).json()
    assert failed["charged"] == 0 and failed["star"]["analysis_failed"] is True and failed["coins"] == 100

    # The next Korean day brings a new free one.
    monkeypatch.setattr("youniya_api.allowance.today", lambda: "2099-01-01")
    assert _me(client, h)[0] == 1


def test_telescope_month_and_sign_up_story(make_app, monkeypatch):
    client = _client(make_app)
    h = sign_in(client)
    float_star(client, h)
    for _ in range(2):
        assert client.post("/v1/telescope/reports", json={}, headers=h).json()["charged"] == 0
    assert _me(client, h)[1] == 0
    assert client.post("/v1/telescope/reports", json={}, headers=h).json()["error"]["cost"] == 20
    # A new month brings one more; the unused ones never pile up.
    monkeypatch.setattr("youniya_api.allowance.this_month", lambda: "2099-01")
    assert client.get("/v1/telescope/offer", headers=h).json() | {"coins": None} == {
        "free": True, "free_left": 1, "cost": 0, "coins": None, "enough": True}
    assert client.post("/v1/telescope/reports", json={}, headers=h).json()["charged"] == 0
    assert _me(client, h)[1] == 0


def test_packages_on_sale_and_old_ones_still_accepted(client):
    h = sign_in(client)
    shop = client.get("/v1/coins", headers=h).json()
    assert shop["packages"] == [
        {"product_id": "coin_110", "coins": 110, "price": 1100, "bonus": 0},
        {"product_id": "coin_330", "coins": 330, "price": 3300, "bonus": 0},
        {"product_id": "coin_1100", "coins": 1100, "price": 9900, "bonus": 100},
    ]
    assert shop["prices"] == {"star": 5, "telescope": 20, "story": 10}
    old = client.post("/v1/coins/purchases", json={"product_id": "coin_50", "transaction_id": "old"}, headers=h)
    assert old.json()["added"] == 50
