"""10.1 별빛 한 줄 on a shared star (20261109)."""

from .conftest import DEEP_BODY, float_star, sign_in

QUOTE = DEEP_BODY.split(". ")[0] + "."


def _shared(client, h, **kw):
    star = float_star(client, h)
    sid = client.put(f"/v1/stars/{star['id']}/share", json={"quote": QUOTE, **kw}, headers=h).json()["share_id"]
    return star, sid


def test_leave_read_and_keep(client):
    owner, a, b = sign_in(client), sign_in(client, "a"), sign_in(client, "b")
    client.put("/v1/me/nickname", json={"name": "다정별"}, headers=a)
    star, sid = _shared(client, owner)
    r = client.post(f"/v1/plaza/stars/{sid}/lines", json={"text": "오늘 그 마음이 오래 머물렀어요"}, headers=a)
    assert r.status_code == 201, r.text
    assert client.post(f"/v1/plaza/stars/{sid}/lines", json={"chip": "me_too"}, headers=a).json()["error"]["code"] \
        == "already_left"
    chip = client.post(f"/v1/plaza/stars/{sid}/lines", json={"chip": "empathize"}, headers=b).json()
    assert chip["text"] == "공감해요" and chip["chip"] == "empathize"
    assert client.post(f"/v1/plaza/stars/{sid}/lines", json={"text": "x"}, headers=owner).status_code == 422

    # Others see only that they left one; never the lines or how many.
    item = client.get(f"/v1/plaza/stars/{sid}", headers=a).json()
    assert item["line_left"] is True and item["receive_lines"] is True and "line_count" not in item
    assert client.get(f"/v1/plaza/stars/{sid}", headers=sign_in(client, "c")).json()["line_left"] is False
    assert client.get(f"/v1/stars/{star['id']}/lines", headers=a).status_code == 404

    lines = client.get(f"/v1/stars/{star['id']}/lines", headers=owner).json()
    assert lines["count"] == 2 and lines["items"][1]["nickname"] == "다정별"
    assert client.get(f"/v1/stars/{star['id']}", headers=owner).json()["line_count"] == 2
    assert client.get("/v1/me/shares", headers=owner).json()["stars"][0]["lines"] == 2
    # Off the plaza: the lines stay.
    client.delete(f"/v1/stars/{star['id']}/share", headers=owner)
    assert client.get(f"/v1/stars/{star['id']}/lines", headers=owner).json()["count"] == 2
    one = lines["items"][0]["id"]
    assert client.delete(f"/v1/stars/{star['id']}/lines/{one}", headers=owner).status_code == 204
    assert client.get(f"/v1/stars/{star['id']}/lines", headers=owner).json()["count"] == 1


def test_filters_and_closed(client):
    owner, a = sign_in(client), sign_in(client, "a")
    _, sid = _shared(client, owner)
    for text, code in (("너 진짜 한심하다", "hurtful"), ("010-1234-5678로 연락해", "contact"),
                       ("그건 네 잘못이야", "judging"), ("상담 받아 보세요", "advice"), ("가" * 61, "too_long")):
        r = client.post(f"/v1/plaza/stars/{sid}/lines", json={"text": text}, headers=a)
        assert r.status_code == 422 and r.json()["error"]["code"] == code, text
    _, closed = _shared(client, owner, receive_lines=False)
    r = client.post(f"/v1/plaza/stars/{closed}/lines", json={"chip": "thanks"}, headers=a)
    assert r.status_code == 403 and r.json()["error"]["code"] == "lines_closed"


def test_owner_reports_and_blocks(client):
    owner, a = sign_in(client), sign_in(client, "a")
    star, sid = _shared(client, owner)
    line = client.post(f"/v1/plaza/stars/{sid}/lines", json={"text": "따뜻한 별이에요"}, headers=a).json()
    r = client.post(f"/v1/stars/{star['id']}/lines/{line['id']}/report", json={"reason": "harassment", "block": True},
                    headers=owner).json()
    assert r == {"reported": True, "blocked": True}
    assert client.get(f"/v1/stars/{star['id']}/lines", headers=owner).json()["count"] == 0
    assert client.get("/v1/plaza/stars", headers=a).json()["items"] == []  # blocked both ways
