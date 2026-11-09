"""알림함 (Mobile 130) and the rename request keeping a keeper's stars off the plaza (20261109)."""

from fastapi.testclient import TestClient

from youniya_api import marketing
from youniya_api.models import User

from .conftest import DEEP_BODY, float_star, sign_in
from .test_admin_auth import _operator, _sign_in

QUOTE = DEEP_BODY.split(". ")[0] + "."


def test_inbox_keeps_what_was_sent(make_app):
    client = TestClient(make_app(admin_token="op-token"))
    oh, _ = _sign_in(client, _operator(client))
    owner, reporter = sign_in(client, "owner"), sign_in(client, "reporter")
    star = float_star(client, owner)
    sid = client.put(f"/v1/stars/{star['id']}/share", json={"quote": QUOTE}, headers=owner).json()["share_id"]
    client.post(f"/v1/plaza/star/{sid}/report", json={"reason": "hate"}, headers=reporter)
    client.post(f"/v1/admin/reports/star/{sid}/actions", json={"action": "take_down", "reason": "혐오"}, headers=oh)

    mine = client.get("/v1/me/notifications", headers=owner).json()
    assert mine["unread"] == 1 and mine["items"][0]["target"] == {"screen": "star", "star_id": star["id"]}
    theirs = client.get("/v1/me/notifications", headers=reporter).json()["items"]
    assert theirs[0]["title"] == "신고하신 내용을 살펴봤어요" and theirs[0]["target"] == {"screen": "notifications"}

    keeper = client.get(f"/v1/admin/reports/star/{sid}", headers=oh).json()["keeper"]["id"]
    client.post(f"/v1/admin/keepers/{keeper}/actions", json={"action": "grant_coins", "amount": 50, "reason": "보상"},
                headers=oh)
    items = client.get("/v1/me/notifications", headers=owner).json()
    assert items["unread"] == 2 and items["items"][0]["target"] == {"screen": "coin_history"}
    one = items["items"][0]["id"]
    assert client.post("/v1/me/notifications/read", json={"ids": [one]}, headers=owner).json()["unread"] == 1
    assert client.post("/v1/me/notifications/read", json={"all": True}, headers=owner).json()["unread"] == 0
    with client.app.state.sessions() as db:
        marketing.set_consent(db, None, db.get(User, keeper), True)  # no device: kept all the same
        db.commit()
    assert client.get("/v1/me/notifications", headers=owner).json()["items"][0]["kind"] == "consent_result"


def test_rename_request_keeps_new_shares_off(make_app):
    client = TestClient(make_app(admin_token="op-token"))
    oh, _ = _sign_in(client, _operator(client))
    owner, reporter = sign_in(client, "owner"), sign_in(client, "reporter")
    client.put("/v1/me/nickname", json={"name": "운영별아님"}, headers=owner)
    first = float_star(client, owner)
    sid = client.put(f"/v1/stars/{first['id']}/share", json={"quote": QUOTE}, headers=owner).json()["share_id"]
    client.post(f"/v1/plaza/star/{sid}/report", json={"reason": "nickname"}, headers=reporter)
    keeper = client.get("/v1/admin/reports/nickname/" + client.get("/v1/admin/reports", headers=oh).json()["items"][0]
                        ["target_id"], headers=oh).json()["keeper"]["id"]
    client.post(f"/v1/admin/keepers/{keeper}/actions", json={"action": "request_rename", "reason": "사칭"}, headers=oh)
    second = float_star(client, owner)
    r = client.put(f"/v1/stars/{second['id']}/share", json={"quote": QUOTE}, headers=owner)
    assert r.status_code == 403 and r.json()["error"]["code"] == "nickname_rename_required"
    client.put("/v1/me/nickname", json={"name": "새벽산책"}, headers=owner)
    assert client.put(f"/v1/stars/{second['id']}/share", json={"quote": QUOTE}, headers=owner).status_code == 200
