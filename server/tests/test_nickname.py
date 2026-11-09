"""별지기 이름 (15장), 별지기 페이지, 18.3 신고 즉시 숨김 (20261109)."""

from datetime import datetime, timedelta, timezone

from youniya_api.models import User

from .conftest import DEEP_BODY, float_star, sign_in

QUOTE = DEEP_BODY.split(". ")[0] + "."


def test_check_and_set(client):
    h, other = sign_in(client), sign_in(client, "other")
    assert client.get("/v1/me", headers=h).json()["nickname"] is None

    def check(name, headers=h):
        return client.get("/v1/me/nickname/check", params={"name": name}, headers=headers).json()["reason"]

    assert check("별") == "form" and check("별지기!") == "form" and check("a" * 13) == "form"
    assert check("운영자별") == "reserved" and check("YOUNIYA1") == "reserved" and check("시발별") == "hurtful"
    assert check("새벽별") is None
    r = client.put("/v1/me/nickname", json={"name": "새벽별"}, headers=h)
    assert r.status_code == 200 and r.json()["nickname"] == "새벽별" and r.json()["next_change"]
    assert check("새벽별", other) == "taken" and check("새벽별") is None  # mine
    assert client.put("/v1/me/nickname", json={"name": "Moon2"}, headers=other).status_code == 200
    taken = client.put("/v1/me/nickname", json={"name": "moon2"}, headers=h)  # case does not matter
    assert taken.status_code in (409, 429)
    soon = client.put("/v1/me/nickname", json={"name": "저녁별"}, headers=h)
    assert soon.status_code == 429 and soon.json()["error"]["code"] == "nickname_too_soon"
    assert client.get("/v1/me", headers=h).json()["nickname"] == "새벽별"


def test_change_after_thirty_days(client, make_app):
    h = sign_in(client)
    client.put("/v1/me/nickname", json={"name": "새벽별"}, headers=h)
    with client.app.state.sessions() as db:
        u = db.query(User).filter(User.nickname == "새벽별").one()
        u.nickname_changed_at = datetime.now(timezone.utc) - timedelta(days=31)
        db.commit()
    assert client.put("/v1/me/nickname", json={"name": "저녁별"}, headers=h).status_code == 200
    assert client.get("/v1/me/nickname/check", params={"name": "새벽별"}, headers=h).json()["available"] is True


def test_keeper_page_and_plaza_nickname(client):
    h, other, blocked = sign_in(client), sign_in(client, "other"), sign_in(client, "blocked")
    client.put("/v1/me/nickname", json={"name": "새벽별"}, headers=h)
    shared = float_star(client, h)
    float_star(client, h)  # not shared
    sid = client.put(f"/v1/stars/{shared['id']}/share", json={"quote": QUOTE}, headers=h).json()["share_id"]
    item = client.get("/v1/plaza/stars", headers=other).json()["items"][0]
    assert item["nickname"] == "새벽별"
    page = client.get("/v1/keepers/새벽별", headers=other).json()
    assert page["nickname"] == "새벽별" and [i["id"] for i in page["items"]] == [sid] and page["mine"] is False
    assert "'starlight'" not in str(page) and "resonances" not in str(page)
    assert client.get("/v1/keepers/없는별", headers=other).status_code == 404
    client.post(f"/v1/plaza/star/{sid}/report", json={"reason": "hurtful", "block": True}, headers=blocked)
    assert client.get("/v1/keepers/새벽별", headers=blocked).status_code == 404


def test_urgent_reasons_hide_at_once(client):
    h, a, b = sign_in(client), sign_in(client, "a"), sign_in(client, "b")
    one, two = float_star(client, h), float_star(client, h)
    s1 = client.put(f"/v1/stars/{one['id']}/share", json={"quote": QUOTE}, headers=h).json()["share_id"]
    s2 = client.put(f"/v1/stars/{two['id']}/share", json={"quote": QUOTE}, headers=h).json()["share_id"]
    client.post(f"/v1/plaza/star/{s1}/report", json={"reason": "self_harm"}, headers=a)
    client.post(f"/v1/plaza/star/{s2}/report", json={"reason": "harassment"}, headers=a)
    assert [i["id"] for i in client.get("/v1/plaza/stars", headers=b).json()["items"]] == [s2]
