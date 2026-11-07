"""차단 (App Store 1.2): made from a line, star or nebula; hides both ways; never says who."""

from .conftest import float_star, sign_in


def _shared(client, h, name="성운"):
    ids = [float_star(client, h)["id"] for _ in range(3)]
    star = client.put(f"/v1/stars/{ids[0]}/share", json={"quote": "걔 소식 듣고 축하한다고 말하면서 속이 쓰렸다."},
                      headers=h).json()
    n = client.post("/v1/nebulae", json={"name": name, "star_ids": ids}, headers=h).json()
    nebula = client.put(f"/v1/nebulae/{n['id']}/share", json={}, headers=h).json()
    return star["share_id"], nebula["share_id"]


def _plaza(client, h):
    stars = [i["id"] for i in client.get("/v1/plaza/stars", headers=h).json()["items"]]
    nebulae = [i["id"] for i in client.get("/v1/plaza/nebulae", params={"filter": "new"}, headers=h).json()["items"]]
    return stars, nebulae


def test_block_from_a_line_hides_both_ways(client):
    me, writer, owner = sign_in(client, "me"), sign_in(client, "writer"), sign_in(client, "owner")
    w_star, w_nebula = _shared(client, writer, "작성자 성운")
    _, o_nebula = _shared(client, owner)
    m_star, m_nebula = _shared(client, me, "내 성운")
    line = client.post(f"/v1/plaza/nebulae/{o_nebula}/lines", json={"text": "고마워요"}, headers=writer).json()
    client.post(f"/v1/plaza/nebulae/{m_nebula}/lines", json={"text": "잘 봤어요"}, headers=writer)

    r = client.post("/v1/blocks", json={"line_id": line["id"]}, headers=me)
    assert r.status_code == 201 and set(r.json()) == {"id", "created_at", "source"} and r.json()["source"] == "line"

    # I no longer see anything of theirs: plaza, details, lines, even on my own nebula.
    stars, nebulae = _plaza(client, me)
    assert w_star not in stars and w_nebula not in nebulae
    assert client.get(f"/v1/plaza/stars/{w_star}", headers=me).status_code == 404
    assert client.get(f"/v1/plaza/nebulae/{w_nebula}", headers=me).status_code == 404
    assert client.put(f"/v1/plaza/star/{w_star}/resonance", json={}, headers=me).status_code == 404
    assert client.get(f"/v1/plaza/nebulae/{o_nebula}/lines", headers=me).json()["items"] == []
    assert client.get(f"/v1/plaza/nebulae/{m_nebula}/lines", headers=me).json()["items"] == []
    assert client.get("/v1/me/shares", headers=me).json()["nebulae"][0]["lines"] == 0
    # …and they no longer see mine, though they were never told.
    stars, nebulae = _plaza(client, writer)
    assert m_star not in stars and m_nebula not in nebulae
    assert client.post(f"/v1/plaza/nebulae/{m_nebula}/lines", json={"text": "또"}, headers=writer).status_code == 404
    # Someone else still sees both.
    stars, _ = _plaza(client, owner)
    assert {w_star, m_star} <= set(stars)

    # The list says when and where, not who. Blocking again is the same block.
    again = client.post("/v1/blocks", json={"star_id": w_star}, headers=sign_in(client, "me"))
    assert again.status_code == 404  # hidden now, so not found from here
    items = client.get("/v1/blocks", headers=me).json()["items"]
    assert items == [r.json()]

    assert client.delete(f"/v1/blocks/{items[0]['id']}", headers=writer).status_code == 404  # not theirs
    assert client.delete(f"/v1/blocks/{items[0]['id']}", headers=me).status_code == 204
    assert w_star in _plaza(client, me)[0]


def test_block_from_a_star_or_nebula_and_bad_requests(client):
    me, other = sign_in(client, "me"), sign_in(client, "other")
    o_star, o_nebula = _shared(client, other)
    _, m_nebula = _shared(client, me)
    assert client.post("/v1/blocks", json={"nebula_id": o_nebula}, headers=me).json()["source"] == "nebula"
    assert client.post("/v1/blocks", json={"star_id": o_star}, headers=me).status_code == 404  # already hidden
    assert len(client.get("/v1/blocks", headers=me).json()["items"]) == 1

    assert client.post("/v1/blocks", json={"nebula_id": m_nebula}, headers=me).status_code == 422  # myself
    assert client.post("/v1/blocks", json={}, headers=me).status_code == 422
    assert client.post("/v1/blocks", json={"star_id": "a", "line_id": "b"}, headers=me).status_code == 422
    assert client.post("/v1/blocks", json={"line_id": "nope"}, headers=me).status_code == 404


def test_report_can_block_too(client):
    me, writer, owner = sign_in(client, "me"), sign_in(client, "writer"), sign_in(client, "owner")
    w_star, _ = _shared(client, writer)
    _, o_nebula = _shared(client, owner)
    line = client.post(f"/v1/plaza/nebulae/{o_nebula}/lines", json={"text": "광고 보러 오세요"}, headers=writer).json()
    r = client.post(f"/v1/plaza/lines/{line['id']}/report", json={"reason": "spam", "block": True}, headers=me)
    assert r.json() == {"reported": True, "blocked": True}
    assert w_star not in _plaza(client, me)[0]
    assert client.get("/v1/blocks", headers=me).json()["items"][0]["source"] == "line"
    plain = client.post(f"/v1/plaza/lines/{line['id']}/report", json={"reason": "spam"}, headers=owner).json()
    assert plain == {"reported": True, "blocked": False}


def test_star_and_nebula_reports(make_app):
    from fastapi.testclient import TestClient

    from .test_push import OP, FakeApns

    app = make_app(admin_token="op-token")
    app.state.push = FakeApns()
    client = TestClient(app)
    owner = sign_in(client, "owner")
    star, nebula = _shared(client, owner)
    r1, r2, r3, viewer = (sign_in(client, n) for n in ("r1", "r2", "r3", "viewer"))

    r = client.post(f"/v1/plaza/star/{star}/report", json={"reason": "hurtful"}, headers=r1)
    assert r.json() == {"reported": True, "blocked": False}
    assert star not in _plaza(client, r1)[0]  # gone for the reporter at once
    assert client.get(f"/v1/plaza/stars/{star}", headers=r1).status_code == 404
    assert star in _plaza(client, viewer)[0]  # still there for others
    client.post(f"/v1/plaza/star/{star}/report", json={"reason": "spam"}, headers=r2)
    client.post(f"/v1/plaza/star/{star}/report", json={"reason": "spam"}, headers=r3)
    assert star not in _plaza(client, viewer)[0]  # three reports take it down
    assert client.get("/v1/me/shares", headers=owner).json()["stars"][0]["hidden"] is True

    reports = client.get("/v1/admin/reports", headers=OP).json()["shares"]
    assert reports == [{"kind": "star", "id": star, "name": "걔 소식을 들은 날", "quote": reports[0]["quote"],
                        "hidden": True, "created_at": reports[0]["created_at"],
                        "reasons": {"hurtful": 1, "spam": 2}, "reports": 3}]
    done = client.post(f"/v1/admin/shares/star/{star}/restore", headers=OP).json()
    assert done["hidden"] is False and done["reporters_told"] == 3
    assert star in _plaza(client, viewer)[0] and star not in _plaza(client, r1)[0]

    r = client.post(f"/v1/plaza/nebula/{nebula}/report", json={"reason": "other", "block": True}, headers=viewer)
    assert r.json() == {"reported": True, "blocked": True}
    assert star not in _plaza(client, viewer)[0]  # the block hides the owner's star too
    assert client.post(f"/v1/plaza/nebula/{nebula}/report", json={"reason": "other"}, headers=owner).status_code == 422
