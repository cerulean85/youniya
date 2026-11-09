"""17.1 별빛 받고 / 별빛 없이 띄우기, 17.5 감정 여러 개, 11.2 고쳐 쓰기, 11.5 별 잇기 (20261109)."""

from fastapi.testclient import TestClient

from .conftest import CALM_BODY, DEEP_BODY, float_star, sign_in

QUOTE = DEEP_BODY.split(". ")[0] + "."


def unlit(client, h, body=CALM_BODY, **kw):
    r = client.post("/v1/stars", json={"mood": "calm", "body": body, "mode": "unlit", **kw}, headers=h)
    assert r.status_code == 201, r.text
    return r.json()


def test_unlit_is_free_and_ten_a_day(make_app):
    client = TestClient(make_app(free_stars_per_day=0))
    h = sign_in(client)
    for _ in range(10):
        r = unlit(client, h)
        assert r["charged"] == 0 and r["star"]["has_starlight"] is False and r["star"]["starlight"] is None
        assert r["star"]["state"] == "kept" and r["star"]["locked"] is False
    r = client.post("/v1/stars", json={"mood": "calm", "body": CALM_BODY, "mode": "unlit"}, headers=h)
    assert r.status_code == 429 and r.json()["error"]["code"] == "unlit_daily_limit" and r.json()["error"]["limit"] == 10
    # "keep" from builds before 20261109 is the same thing.
    assert client.post("/v1/stars", json={"mood": "calm", "body": "x", "mode": "keep"}, headers=h).status_code == 429


def test_lit_and_moods(client):
    h = sign_in(client)
    r = client.post("/v1/stars", json={"moods": ["insight", "sorrow", "insight"], "title": "t", "body": DEEP_BODY,
                                       "mode": "lit"}, headers=h).json()
    star = r["star"]
    assert star["has_starlight"] and star["locked"] and star["starlight"] >= 1
    assert star["mood"] == "insight" and star["moods"] == ["insight", "sorrow"]
    assert client.post("/v1/stars", json={"body": DEEP_BODY, "mode": "lit"}, headers=h).json()["error"]["code"] \
        == "mood_required"
    # Old stars and old clients: one mood is a list of one.
    old = float_star(client, h)
    assert old["moods"] == [old["mood"]]
    assert client.get("/v1/stars?mood=sorrow", headers=h).json()["items"][0]["id"] == star["id"]


def test_starlight_later(make_app):
    client = TestClient(make_app(free_stars_per_day=1))
    h = sign_in(client)
    a, b = unlit(client, h, DEEP_BODY)["star"], unlit(client, h, DEEP_BODY)["star"]
    r = client.post(f"/v1/stars/{a['id']}/starlight", headers=h).json()
    assert r["charged"] == 0 and r["star"]["has_starlight"] and r["star"]["locked"]
    again = client.post(f"/v1/stars/{a['id']}/starlight", headers=h)
    assert again.status_code == 409 and again.json()["error"]["code"] == "already_lit"
    poor = client.post(f"/v1/stars/{b['id']}/starlight", headers=h)
    assert poor.status_code == 402 and poor.json()["error"]["code"] == "insufficient_coins"
    assert client.get("/v1/stars?starlight=unlit", headers=h).json()["items"][0]["id"] == b["id"]
    assert client.get("/v1/stars?starlight=lit", headers=h).json()["items"][0]["id"] == a["id"]


def test_unlit_star_can_be_rewritten_in_place(client):
    h = sign_in(client)
    star = unlit(client, h)["star"]
    r = client.patch(f"/v1/stars/{star['id']}", json={"moods": ["sorrow", "calm"], "body": "다시 쓴 글"}, headers=h)
    assert r.status_code == 200 and r.json()["star"]["moods"] == ["sorrow", "calm"]
    assert r.json()["star"]["mood"] == "sorrow"


def test_rewrite_links_the_new_star(client):
    h = sign_in(client)
    original = float_star(client, h)
    client.put("/v1/drafts/current", json={"moods": ["calm", "insight"], "title": "고쳐 쓰기", "body": "초안",
                                           "source_star_id": original["id"]}, headers=h)
    draft = client.get("/v1/drafts/current", headers=h).json()
    assert draft["source_star_id"] == original["id"] and draft["moods"] == ["calm", "insight"]
    new = unlit(client, h, "다시 쓴 마음")["star"]  # from the draft: no rewrite_of sent
    assert new["rewrite_of"] == original["id"]
    linked = client.get(f"/v1/stars/{original['id']}", headers=h).json()["linked_stars"]
    assert [s["id"] for s in linked] == [new["id"]] and linked[0]["has_starlight"] is False
    # The original keeps its starlight.
    assert client.get(f"/v1/stars/{original['id']}", headers=h).json()["starlight"] == original["starlight"]
    third = client.post("/v1/stars", json={"mood": "calm", "body": "또", "mode": "unlit", "rewrite_of": new["id"]},
                        headers=h).json()["star"]
    assert [s["id"] for s in client.get(f"/v1/stars/{new['id']}", headers=h).json()["linked_stars"]] == [
        original["id"], third["id"]]


def test_links(client):
    h, other = sign_in(client), sign_in(client, "other")
    a, b, c = (unlit(client, h)["star"]["id"] for _ in range(3))
    theirs = unlit(client, other)["star"]["id"]
    r = client.post(f"/v1/stars/{a}/links", json={"star_ids": [b, c, b, a]}, headers=h).json()
    assert r["added"] == 2 and {s["id"] for s in r["linked_stars"]} == {b, c}
    assert client.post(f"/v1/stars/{b}/links", json={"star_ids": [a]}, headers=h).json()["added"] == 0  # no direction
    assert client.post(f"/v1/stars/{a}/links", json={"star_ids": [theirs]}, headers=h).status_code == 422
    assert client.post(f"/v1/stars/{a}/links", json={"star_ids": [a]}, headers=h).status_code == 422
    assert client.delete(f"/v1/stars/{b}/links/{a}", headers=h).status_code == 204
    assert [s["id"] for s in client.get(f"/v1/stars/{a}", headers=h).json()["linked_stars"]] == [c]
    client.delete(f"/v1/stars/{c}", headers=h)
    assert client.get(f"/v1/stars/{a}", headers=h).json()["linked_stars"] == []


def test_unlit_stars_on_the_plaza(client):
    h, other = sign_in(client), sign_in(client, "other")
    plain = unlit(client, h, DEEP_BODY)["star"]
    lit = float_star(client, h)
    plain_share = client.put(f"/v1/stars/{plain['id']}/share", json={"quote": QUOTE, "full_text": True},
                             headers=h).json()["share_id"]
    lit_share = client.put(f"/v1/stars/{lit['id']}/share", json={"quote": QUOTE}, headers=h).json()["share_id"]
    items = client.get("/v1/plaza/stars", headers=other).json()["items"]
    assert [i["id"] for i in items] == [lit_share, plain_share]  # unlit after lit, though newer… or older
    assert items[1]["has_starlight"] is False and items[0]["has_starlight"] is True
    assert [i["id"] for i in client.get("/v1/plaza/stars?sort=similar", headers=other).json()["items"]] == [lit_share]
    # Lit later: the plaza shows its reading.
    client.post(f"/v1/stars/{plain['id']}/starlight", headers=h)
    item = client.get(f"/v1/plaza/stars/{plain_share}", headers=other).json()
    assert item["has_starlight"] is True


def test_new_writing_linked_and_drafts_kept_apart(client):
    h = sign_in(client)
    a, b = unlit(client, h)["star"], unlit(client, h)["star"]
    # A rewrite draft of `a` is kept while an unrelated star is written…
    client.put("/v1/drafts/current", json={"mood": "calm", "body": "고쳐 쓰는 중", "source_star_id": a["id"]}, headers=h)
    new = unlit(client, h, "새 글로 잇기", link_to=[b["id"]])["star"]
    assert new["rewrite_of"] is None
    assert [s["id"] for s in client.get(f"/v1/stars/{new['id']}", headers=h).json()["linked_stars"]] == [b["id"]]
    assert client.get("/v1/drafts/current", headers=h).json()["source_star_id"] == a["id"]
    # …and goes with the rewrite it belongs to.
    unlit(client, h, "고친 글", rewrite_of=a["id"])
    assert client.get("/v1/drafts/current", headers=h).json() is None
    assert client.post("/v1/stars", json={"mood": "calm", "body": "x", "mode": "unlit", "link_to": ["nope"]},
                       headers=h).status_code == 422
