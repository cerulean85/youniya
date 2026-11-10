"""20장 별빛 받기 그만두기: POST /v1/starlight/attempts/{attempt_id}/cancel."""

from fastapi.testclient import TestClient

from youniya_api.prism.engine import PrismEngine
from youniya_api.rules import UNLIT_PER_DAY

from .conftest import DEEP_BODY, sign_in

STAR = {"mood": "insight", "title": "오늘", "body": DEEP_BODY, "mode": "lit"}


def _client(make_app):
    return TestClient(make_app(free_stars_per_day=1))


def _me(client, h):
    me = client.get("/v1/me", headers=h).json()
    return me["free_star_today"], me["coins"]


def _cancel_while_reading(client, monkeypatch, h, attempt):
    """The app stops it while the prism is still reading."""
    real = client.app.state.prism.evaluate
    seen = {}

    def evaluate(title, body):
        seen["cancel"] = client.post(f"/v1/starlight/attempts/{attempt}/cancel", headers=h)
        return real(title, body)
    monkeypatch.setattr(client.app.state.prism, "evaluate", evaluate)
    return seen


def test_cancel_while_reading_a_new_star(make_app, monkeypatch):
    client = _client(make_app)
    h = sign_in(client)
    seen = _cancel_while_reading(client, monkeypatch, h, "attempt-new-1")
    r = client.post("/v1/stars", json=STAR | {"attempt_id": "attempt-new-1"}, headers=h)
    assert r.status_code == 409 and r.json()["error"]["code"] == "starlight_cancelled"
    star_id = r.json()["error"]["star_id"]
    cancel = seen["cancel"].json()
    assert cancel["status"] == "cancelled" and cancel["refunded"] is None and cancel["star"]["id"] == star_id

    star = client.get(f"/v1/stars/{star_id}", headers=h).json()
    assert star["has_starlight"] is False and star["starlight_cancelled"] is True and star["analysis"] is None
    assert star["shape"] is None and star["body"] == DEEP_BODY
    assert _me(client, h)[0] == 1  # the free float was not used
    # 별빛 받기 again on the same star starts afresh.
    monkeypatch.undo()
    again = client.post(f"/v1/stars/{star_id}/starlight", json={"attempt_id": "attempt-new-2"}, headers=h).json()
    assert again["star"]["has_starlight"] is True and again["star"]["starlight_cancelled"] is False
    assert again["star"]["shape"] == again["star"]["analysis"]["shape"]
    assert set(again["star"]["shape"]) == {"points", "sharpness"}

    # The stopped new star counted as one of today's 별빛 없이 띄우기.
    for _ in range(UNLIT_PER_DAY - 1):
        assert client.post("/v1/stars", json=STAR | {"mode": "unlit"}, headers=h).status_code == 201
    assert client.post("/v1/stars", json=STAR | {"mode": "unlit"}, headers=h).status_code == 429


def test_cancel_after_done_gives_everything_back(make_app):
    client = _client(make_app)
    h = sign_in(client)
    client.post("/v1/coins/purchases", json={"product_id": "coin_110", "transaction_id": "a"}, headers=h)
    free = client.post("/v1/stars", json=STAR | {"attempt_id": "attempt-free"}, headers=h).json()
    paid = client.post("/v1/stars", json=STAR | {"attempt_id": "attempt-paid"}, headers=h).json()
    assert free["charged"] == 0 and paid["charged"] == 5 and _me(client, h) == (0, 105)

    # The app lost the answer (timeout, dropped connection): it cancels, and gets the coins back.
    r = client.post("/v1/starlight/attempts/attempt-paid/cancel", headers=h).json()
    assert r["refunded"] == {"used": "coins", "coins": 5} and r["coins"] == 110
    assert r["star"]["has_starlight"] is False and r["star"]["starlight_cancelled"] is True
    assert r["star"]["starlight"] is None and r["star"]["analysis"] is None
    r = client.post("/v1/starlight/attempts/attempt-free/cancel", headers=h).json()
    assert r["refunded"] == {"used": "free", "coins": 0}
    assert _me(client, h) == (1, 110)

    # Sending it again changes nothing.
    again = client.post("/v1/starlight/attempts/attempt-paid/cancel", headers=h).json()
    assert again["status"] == "cancelled" and again["coins"] == 110
    history = client.get("/v1/coins/history", headers=h).json()["items"]
    assert sum(1 for i in history if i["title"] == "별빛 받기 그만두기") == 1


def test_cancel_before_the_request_arrives(make_app):
    client = _client(make_app)
    h = sign_in(client)
    first = client.post("/v1/starlight/attempts/attempt-early/cancel", headers=h).json()
    assert first == {"status": "cancelled", "star": None, "refunded": None, "coins": 0}
    r = client.post("/v1/stars", json=STAR | {"attempt_id": "attempt-early"}, headers=h)
    assert r.status_code == 409 and r.json()["error"]["code"] == "starlight_cancelled"
    star = client.get(f"/v1/stars/{r.json()['error']['star_id']}", headers=h).json()
    assert star["starlight_cancelled"] is True and star["has_starlight"] is False
    assert _me(client, h)[0] == 1

    # An id is used once; another account cannot touch mine.
    assert client.post("/v1/stars", json=STAR | {"attempt_id": "attempt-early"},
                       headers=h).json()["error"]["code"] == "attempt_used"
    other = sign_in(client, sub="user-2")
    assert client.post("/v1/starlight/attempts/attempt-early/cancel", headers=other).status_code == 404


def test_too_short_is_refused_before_anything_is_stored(make_app):
    client = _client(make_app)
    h = sign_in(client)
    r = client.post("/v1/stars", json=STAR | {"body": "짧아요", "attempt_id": "attempt-short"}, headers=h)
    assert r.status_code == 422
    assert client.get("/v1/stars", headers=h).json()["items"] == []


def test_list_carries_the_shape(make_app):
    client = _client(make_app)
    h = sign_in(client)
    client.post("/v1/stars", json=STAR, headers=h)
    client.post("/v1/stars", json=STAR | {"mode": "unlit"}, headers=h)
    items = client.get("/v1/stars", headers=h).json()["items"]
    assert [i["shape"] is None for i in items] == [True, False]
    assert all(i["starlight_cancelled"] is False for i in items)


def test_the_prism_keeps_to_its_deadline(monkeypatch):
    """Every try is cut at the deadline: the server answers before the apps stop waiting."""
    import youniya_api.prism.engine as engine
    calls = []

    def generate_json(*a, timeout, retries=0, deadline=None, **k):
        calls.append((timeout, retries, deadline))
        raise TimeoutError
    monkeypatch.setattr(engine, "generate_json", generate_json)
    assert PrismEngine(api_key="k", model="m").evaluate("t", DEEP_BODY).status == "failed"
    assert calls and all(d is not None for _, _, d in calls)
    assert engine.PRISM_DEADLINE_SECONDS <= 45
