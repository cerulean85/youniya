"""글 수정, floating a kept star later, and the 50-character minimum (20261108)."""

from .conftest import DEEP_BODY, float_star, sign_in

SHORT = "오늘은 그냥 좀 지쳤어요. 해야 할 일은 많은데 마음이 자꾸 창밖으로 나가요. 쉬고 싶었나 봐요."


def test_fifty_characters_float(client):
    h = sign_in(client)
    assert len(SHORT) >= 50
    r = client.post("/v1/stars", json={"mood": "calm", "body": SHORT[:49], "mode": "float"}, headers=h)
    assert r.status_code == 422 and r.json()["error"]["code"] == "too_short"
    assert "50자" in r.json()["error"]["message"]
    assert float_star(client, h, body=SHORT, mood="calm")["state"] == "floated"


def test_edit_kept_star_everything(client):
    h = sign_in(client)
    star = client.post("/v1/stars", json={"mood": "calm", "title": "처음", "body": "짧게 남긴 글", "mode": "keep"},
                       headers=h).json()["star"]
    assert star["updated_at"] is None
    r = client.patch(f"/v1/stars/{star['id']}", json={"mood": "sorrow", "title": "", "body": SHORT}, headers=h)
    assert r.status_code == 200, r.text
    edited = r.json()["star"]
    assert edited["mood"] == "sorrow" and edited["title"] == "제목 없는 별" and edited["body"] == SHORT
    assert edited["updated_at"] and edited["state"] == "kept" and r.json()["charged"] == 0

    # Only the given fields change.
    r = client.patch(f"/v1/stars/{star['id']}", json={"title": "다시 쓴 제목"}, headers=h).json()["star"]
    assert r["title"] == "다시 쓴 제목" and r["body"] == SHORT and r["mood"] == "sorrow"
    assert client.patch(f"/v1/stars/{star['id']}", json={"body": "   "}, headers=h).status_code == 422


def test_edit_floated_star_keeps_its_reading(client):
    h, other = sign_in(client), sign_in(client, "other")
    star = float_star(client, h)
    coins = client.get("/v1/me", headers=h).json()["coins"]
    quote = DEEP_BODY.split(". ")[0] + "."
    share = client.put(f"/v1/stars/{star['id']}/share", json={"quote": quote}, headers=h).json()

    assert client.patch(f"/v1/stars/{star['id']}", json={"mood": "calm"}, headers=h).json()["error"]["code"] \
        == "mood_fixed"
    r = client.patch(f"/v1/stars/{star['id']}", json={"title": "고친 제목", "body": "완전히 새로 쓴 본문",
                                                      "mood": star["mood"]}, headers=h)
    assert r.status_code == 200, r.text
    edited = r.json()["star"]
    assert edited["body"] == "완전히 새로 쓴 본문" and edited["title"] == "고친 제목"
    assert edited["starlight"] == star["starlight"] and edited["analysis"] == star["analysis"]
    assert edited["state"] == "floated" and client.get("/v1/me", headers=h).json()["coins"] == coins

    # The plaza keeps what was shared.
    item = client.get("/v1/plaza/stars", headers=other).json()["items"][0]
    assert item["id"] == share["share_id"] and item["quote"] == share["quote"]
    assert "고친" not in str(item)


def test_edit_runs_the_crisis_check_again(client):
    h = sign_in(client)
    star = client.post("/v1/stars", json={"mood": "sorrow", "body": SHORT, "mode": "keep"}, headers=h).json()["star"]
    r = client.patch(f"/v1/stars/{star['id']}", json={"body": SHORT + " 그냥 사라지고 싶다."}, headers=h).json()
    assert r["crisis"] is not None
    # A kept star in crisis is not scored when floated…
    assert client.post(f"/v1/stars/{star['id']}/float", headers=h).json()["star"]["state"] == "kept"
    # …until the writing no longer carries the signal.
    assert client.patch(f"/v1/stars/{star['id']}", json={"body": SHORT}, headers=h).json()["crisis"] is None
    assert client.post(f"/v1/stars/{star['id']}/float", headers=h).json()["star"]["state"] == "floated"


def test_float_kept_star_later(client, make_app):
    h = sign_in(client)
    kept = client.post("/v1/stars", json={"mood": "calm", "body": "짧은 글", "mode": "keep"}, headers=h).json()["star"]
    r = client.post(f"/v1/stars/{kept['id']}/float", headers=h)
    assert r.status_code == 422 and r.json()["error"]["code"] == "too_short"
    client.patch(f"/v1/stars/{kept['id']}", json={"body": SHORT}, headers=h)
    r = client.post(f"/v1/stars/{kept['id']}/float", headers=h)
    assert r.status_code == 200 and r.json()["star"]["state"] == "floated"
    again = client.post(f"/v1/stars/{kept['id']}/float", headers=h)
    assert again.status_code == 409 and again.json()["error"]["code"] == "already_floated"


def test_float_later_follows_the_daily_rule(make_app):
    from fastapi.testclient import TestClient

    client = TestClient(make_app(free_stars_per_day=1))
    h = sign_in(client)
    ids = [client.post("/v1/stars", json={"mood": "calm", "body": SHORT, "mode": "keep"}, headers=h).json()["star"]["id"]
           for _ in range(2)]
    first = client.post(f"/v1/stars/{ids[0]}/float", headers=h).json()
    assert first["charged"] == 0
    second = client.post(f"/v1/stars/{ids[1]}/float", headers=h)
    assert second.status_code == 402 and second.json()["error"]["code"] == "insufficient_coins"


def test_cannot_edit_someone_elses_star(client):
    owner, other = sign_in(client, "owner"), sign_in(client, "other")
    star = float_star(client, owner)
    assert client.patch(f"/v1/stars/{star['id']}", json={"title": "x"}, headers=other).status_code == 404


def test_tonight_counts_stars_by_when_they_floated(client):
    """69 오늘 밤: a star kept yesterday and floated today counts; one floated yesterday does not."""
    from datetime import timedelta

    from youniya_api.models import Star

    h = sign_in(client)
    kept = client.post("/v1/stars", json={"mood": "calm", "body": SHORT, "mode": "keep"}, headers=h).json()["star"]
    old = client.post("/v1/stars", json={"mood": "calm", "body": SHORT, "mode": "float"}, headers=h).json()["star"]
    with client.app.state.sessions() as db:
        for star_id in (kept["id"], old["id"]):
            row = db.get(Star, star_id)
            row.created_at -= timedelta(days=2)
            if row.floated_at:
                row.floated_at -= timedelta(days=2)
        db.commit()
    assert client.get("/v1/plaza/tonight", headers=h).json() == {"count": 0, "mine": 0}
    client.post(f"/v1/stars/{kept['id']}/float", headers=h)
    assert client.get("/v1/plaza/tonight", headers=h).json() == {"count": 1, "mine": 1}
