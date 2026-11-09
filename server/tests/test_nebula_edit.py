"""성운 다시 그리기: PATCH /v1/nebulae/{id} (20261108)."""

from .conftest import DEEP_BODY, float_star, sign_in

QUOTE = DEEP_BODY.split(". ")[0] + "."
OTHER = "오늘은 비가 와서 오래 걸었다. 우산을 쓰고도 젖은 신발이 이상하게 싫지 않았다. 마음이 조금 가라앉았다. " * 2


def _nebula(client, h, ids, **kw):
    r = client.post("/v1/nebulae", json={"name": "처음 성운", "star_ids": ids, **kw}, headers=h)
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_redraw_changes_only_what_is_given(client):
    h = sign_in(client)
    ids = [float_star(client, h)["id"] for _ in range(4)]
    nid = _nebula(client, h, ids[:3], silhouette="whale", edges=[[0, 1]])
    before = client.get(f"/v1/nebulae/{nid}", headers=h).json()
    assert before["updated_at"] is None
    assert {"id", "index", "mood", "shape", "depth_level", "created_at"} <= set(before["stars"][0])

    r = client.patch(f"/v1/nebulae/{nid}", json={"name": "다시 그린 성운"}, headers=h).json()
    assert r["name"] == "다시 그린 성운" and r["silhouette"] == "whale" and r["edges"] == [[0, 1]]
    assert r["updated_at"] and r["plaza_updated"] is False

    r = client.patch(f"/v1/nebulae/{nid}", json={"silhouette": None, "star_ids": ids, "edges": [[0, 3], [1, 2]]},
                     headers=h).json()
    assert r["silhouette"] is None and r["star_count"] == 4 and r["edges"] == [[0, 3], [1, 2]]
    listed = client.get("/v1/nebulae", headers=h).json()["mine"][0]
    assert listed["updated_at"] == r["updated_at"]


def test_redraw_checks_like_drawing(client):
    h, other = sign_in(client), sign_in(client, "other")
    ids = [float_star(client, h)["id"] for _ in range(3)]
    theirs = float_star(client, other)["id"]
    kept = client.post("/v1/stars", json={"mood": "calm", "body": "짧은 글", "mode": "keep"}, headers=h).json()["star"]
    nid = _nebula(client, h, ids)

    def code(body):
        r = client.patch(f"/v1/nebulae/{nid}", json=body, headers=h)
        return r.status_code, r.json()["error"]["code"]

    assert code({"star_ids": ids}) == (422, "edges_required")
    assert code({"star_ids": ids[:2], "edges": []})[0] == 422
    assert code({"star_ids": ids[:2] + [kept["id"]], "edges": []}) == (422, "invalid_stars")
    assert code({"star_ids": ids[:2] + [theirs], "edges": []}) == (422, "invalid_stars")
    assert code({"edges": [[0, 5]]}) == (422, "invalid_edges")
    assert code({"silhouette": "dragon"}) == (422, "unknown_silhouette")
    assert code({"guest_share_ids": ["nope"]}) == (422, "invalid_guests")
    assert client.patch(f"/v1/nebulae/{nid}", json={"name": "x"}, headers=other).status_code == 404


def test_new_stars_join_the_story(client):
    h = sign_in(client)
    ids = [float_star(client, h)["id"] for _ in range(4)]
    nid = _nebula(client, h, ids[:3])
    assert client.get(f"/v1/nebulae/{nid}/story", headers=h).json()["star_count"] == 3
    client.patch(f"/v1/nebulae/{nid}", json={"star_ids": ids, "edges": []}, headers=h)
    assert client.get(f"/v1/nebulae/{nid}/story", headers=h).json()["star_count"] == 4


def test_shared_nebula_follows_on_the_plaza(client):
    h, guest = sign_in(client), sign_in(client, "guest")
    deep = [float_star(client, h)["id"] for _ in range(3)]
    calm = [float_star(client, h, body=OTHER, title="비", mood="calm")["id"] for _ in range(3)]
    nid = _nebula(client, h, deep, silhouette="whale")
    share = client.put(f"/v1/nebulae/{nid}/share", json={"quote": QUOTE, "receive_lines": True}, headers=h).json()
    sid = share["share_id"]
    client.put(f"/v1/plaza/nebula/{sid}/resonance", json={}, headers=guest)
    assert client.post(f"/v1/plaza/nebulae/{sid}/lines", json={"text": "따뜻한 성운이에요"}, headers=guest).status_code < 300

    # Still holds a star with the quote: the quote stays.
    r = client.patch(f"/v1/nebulae/{nid}", json={"name": "민지 씨의 성운", "silhouette": "flower",
                                                 "star_ids": deep[:1] + calm[:2], "edges": [[0, 1]]}, headers=h).json()
    assert r["plaza_updated"] is True
    seen = client.get(f"/v1/plaza/nebulae/{sid}", headers=guest).json()
    assert seen["shape"]["silhouette"] == "flower" and len(seen["shape"]["stars"]) == 3
    assert "민지" not in seen["name"] and seen["quote"] == share["quote"]

    # No star holds the quote any more: the quote goes, the rest stays.
    client.patch(f"/v1/nebulae/{nid}", json={"star_ids": calm, "edges": []}, headers=h)
    seen = client.get(f"/v1/plaza/nebulae/{sid}", headers=guest).json()
    assert seen["quote"] is None and seen["receive_lines"] is True
    mine = client.get("/v1/me/shares", headers=h).json()["nebulae"][0]
    assert mine["resonances"] == 1


def test_crisis_star_keeps_the_plaza_as_it_was(client):
    h, guest = sign_in(client), sign_in(client, "guest")
    ids = [float_star(client, h)["id"] for _ in range(4)]
    nid = _nebula(client, h, ids[:3], silhouette="whale")
    sid = client.put(f"/v1/nebulae/{nid}/share", json={}, headers=h).json()["share_id"]
    client.patch(f"/v1/stars/{ids[3]}", json={"title": "그냥 사라지고 싶다"}, headers=h)
    r = client.patch(f"/v1/nebulae/{nid}", json={"silhouette": "flower", "star_ids": ids, "edges": []},
                     headers=h).json()
    assert r["silhouette"] == "flower" and r["plaza_updated"] is False
    seen = client.get(f"/v1/plaza/nebulae/{sid}", headers=guest).json()
    assert seen["shape"]["silhouette"] == "whale" and len(seen["shape"]["stars"]) == 3


def test_a_guest_that_left_the_plaza_does_not_block_editing(client):
    h, friend = sign_in(client), sign_in(client, "friend")
    ids = [float_star(client, h)["id"] for _ in range(3)]
    fstar = float_star(client, friend)["id"]
    gid = client.put(f"/v1/stars/{fstar}/share", json={"quote": QUOTE}, headers=friend).json()["share_id"]
    nid = _nebula(client, h, ids, guest_share_ids=[gid])
    client.delete(f"/v1/stars/{fstar}/share", headers=friend)
    r = client.patch(f"/v1/nebulae/{nid}", json={"name": "새 이름", "silhouette": None, "star_ids": ids, "edges": [],
                                                 "guest_share_ids": [gid]}, headers=h)
    assert r.status_code == 200 and r.json()["guests"] == []
    # Once let go, it cannot be invited back while it is off the plaza.
    assert client.patch(f"/v1/nebulae/{nid}", json={"guest_share_ids": [gid]}, headers=h).status_code == 422
