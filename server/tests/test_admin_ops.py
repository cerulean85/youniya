"""관리자 콘솔 신고·별지기·문의 (18장, step 7-2)."""

from fastapi.testclient import TestClient

from .conftest import DEEP_BODY, float_star, sign_in
from .test_admin_auth import _operator, _sign_in

QUOTE = DEEP_BODY.split(". ")[0] + "."
TOKEN = {"X-Admin-Token": "op-token"}


def _setup(make_app, **kw):
    client = TestClient(make_app(admin_token="op-token", **kw))
    oh, _ = _sign_in(client, _operator(client))
    mh, _ = _sign_in(client, _operator(client, "mod@youniya.app", "moderator", oh), "mod@youniya.app")
    return client, oh, mh


def _shared_star(client, owner):
    star = float_star(client, owner)
    return client.put(f"/v1/stars/{star['id']}/share", json={"quote": QUOTE, "full_text": True},
                      headers=owner).json()["share_id"]


def test_reports_list_detail_and_take_down(make_app):
    client, oh, mh = _setup(make_app)
    owner, r1, r2 = sign_in(client, "owner"), sign_in(client, "r1"), sign_in(client, "r2")
    client.put("/v1/me/nickname", json={"name": "새벽별"}, headers=owner)
    sid = _shared_star(client, owner)
    client.post(f"/v1/plaza/star/{sid}/report", json={"reason": "hate"}, headers=r1)
    client.post(f"/v1/plaza/star/{sid}/report", json={"reason": "nickname"}, headers=r2)

    listed = client.get("/v1/admin/reports", headers=mh).json()
    kinds = {(i["kind"], i["status"]) for i in listed["items"]}
    assert kinds == {("star", "pending"), ("nickname", "pending")} and listed["counts"]["pending"] == 2
    d = client.get(f"/v1/admin/reports/star/{sid}", headers=mh).json()
    assert d["content"]["full_text"] and d["content"]["body_masked"] and d["keeper"]["nickname"] == "새벽별"
    assert d["reports"] == [{"reporter_no": 1, "reason": "hate", "at": d["reports"][0]["at"], "note": None}]
    assert "starlight" not in str(d) and d["auto_hidden"] is False

    assert client.post(f"/v1/admin/reports/star/{sid}/actions", json={"action": "take_down"}, headers=mh).status_code == 422
    r = client.post(f"/v1/admin/reports/star/{sid}/actions", json={"action": "take_down", "reason": "혐오 표현"},
                    headers=mh).json()
    assert r["status"] == "done"
    assert client.get("/v1/plaza/stars", headers=sign_in(client, "viewer")).json()["items"] == []
    d = client.get(f"/v1/admin/reports/star/{sid}", headers=mh).json()
    assert d["actions"][0]["action"] == "report_take_down" and d["actions"][0]["reason"] == "혐오 표현"

    keeper_id = d["keeper"]["id"]
    client.post(f"/v1/admin/reports/nickname/{keeper_id}/actions", json={"action": "request_rename", "reason": "사칭"},
                headers=mh)
    me = client.get("/v1/me", headers=owner).json()
    assert me["nickname_rename_required"] is True and me["nickname_next_change"] is None
    assert client.put("/v1/me/nickname", json={"name": "새이름"}, headers=owner).status_code == 200  # no 30-day wait
    assert client.get("/v1/me", headers=owner).json()["nickname_rename_required"] is False


def test_plaza_restriction(make_app):
    client, oh, mh = _setup(make_app)
    owner, r1 = sign_in(client, "owner"), sign_in(client, "r1")
    sid = _shared_star(client, owner)
    client.post(f"/v1/plaza/star/{sid}/report", json={"reason": "harassment"}, headers=r1)
    keeper_id = client.get(f"/v1/admin/reports/star/{sid}", headers=mh).json()["keeper"]["id"]
    client.post(f"/v1/admin/reports/star/{sid}/actions", json={"action": "restrict_7d", "reason": "괴롭힘"}, headers=mh)
    star = float_star(client, owner)
    r = client.put(f"/v1/stars/{star['id']}/share", json={"quote": QUOTE}, headers=owner)
    assert r.status_code == 403 and r.json()["error"]["code"] == "plaza_restricted" and r.json()["error"]["until"]
    assert client.post(f"/v1/plaza/stars/{sid}/lines", json={"chip": "thanks"}, headers=owner).status_code == 403
    assert float_star(client, owner)["state"] == "floated"  # writing is not restricted
    k = client.get(f"/v1/admin/keepers/{keeper_id}", headers=mh).json()
    assert k["status"] == "restricted" and k["history"] == []
    client.post(f"/v1/admin/keepers/{keeper_id}/actions", json={"action": "lift_restriction", "reason": "소명"}, headers=mh)
    assert client.put(f"/v1/stars/{star['id']}/share", json={"quote": QUOTE}, headers=owner).status_code == 200


def test_keepers_search_and_owner_only_actions(make_app):
    client, oh, mh = _setup(make_app)
    a = sign_in(client, "a")
    client.put("/v1/me/nickname", json={"name": "다정한바람"}, headers=a)
    found = client.get("/v1/admin/keepers", params={"q": "다정"}, headers=mh).json()["items"]
    assert len(found) == 1 and found[0]["nickname"] == "다정한바람" and found[0]["no"]
    by_no = client.get("/v1/admin/keepers", params={"q": f"#{found[0]['no']}"}, headers=mh).json()["items"]
    assert [k["id"] for k in by_no] == [found[0]["id"]]
    kid = found[0]["id"]
    detail = client.get(f"/v1/admin/keepers/{kid}", headers=mh).json()
    assert detail["consents"]["terms_at"] and detail["star_counts"] == {"lit": 0, "unlit": 0}
    grant = {"action": "grant_coins", "reason": "보상", "amount": 100}
    denied = client.post(f"/v1/admin/keepers/{kid}/actions", json=grant, headers=mh)
    assert denied.status_code == 403 and denied.json()["error"]["code"] == "forbidden_role"
    assert client.post(f"/v1/admin/keepers/{kid}/actions", json=grant, headers=oh).json()["coins"] == 100
    assert client.get("/v1/coins/history", headers=a).status_code in (200, 404)
    assert client.get("/v1/admin/keepers", params={"format": "csv"}, headers=mh).status_code == 403
    csv = client.get("/v1/admin/keepers", params={"format": "csv"}, headers=oh)
    assert csv.status_code == 200 and "다정한바람" in csv.text
    gone = client.post(f"/v1/admin/keepers/{kid}/actions", json={"action": "process_deletion", "reason": "본인 요청"},
                       headers=oh).json()
    assert gone == {"deleted": True} and client.get(f"/v1/admin/keepers/{kid}", headers=oh).status_code == 404
    assert any(i["action"] == "keeper_process_deletion" for i in client.get("/v1/admin/audit", headers=oh).json()["items"])


def test_inquiry_reply(make_app, monkeypatch):
    sent = []
    from youniya_api import mailer

    monkeypatch.setattr(mailer, "send", lambda key, sender, to, subject, text: sent.append((to, subject, text)) or "id1")
    client, oh, mh = _setup(make_app, resend_api_key="re_test")
    u = sign_in(client, "u")
    iid = client.post("/v1/inquiries", json={"kind": "payment", "email": "someone@example.com", "body": "결제가 안 돼요\n자세히"},
                      headers=u | {"X-App-Version": "1.1.0", "X-App-Platform": "ios"}).json()["id"]
    listed = client.get("/v1/admin/inquiries", headers=mh).json()
    assert listed["counts"] == {"new": 1, "answered": 0} and listed["items"][0]["title"] == "결제가 안 돼요"
    d = client.get(f"/v1/admin/inquiries/{iid}", headers=mh).json()
    assert d["email_masked"] == "so●●●●●@example.com" and d["app"]["version"] == "1.1.0"
    r = client.post(f"/v1/admin/inquiries/{iid}/reply", json={"body": "확인해 볼게요."}, headers=mh).json()
    assert r["status"] == "answered" and r["replies"][0]["body"] == "확인해 볼게요."
    assert sent[0][0] == "someone@example.com" and "확인해 볼게요." in sent[0][2]


def test_reply_needs_the_mail_key(make_app):
    client, oh, mh = _setup(make_app)
    u = sign_in(client, "u")
    iid = client.post("/v1/inquiries", json={"kind": "other", "email": "a@b.co", "body": "질문"}, headers=u).json()["id"]
    r = client.post(f"/v1/admin/inquiries/{iid}/reply", json={"body": "답"}, headers=oh)
    assert r.status_code == 503 and r.json()["error"]["code"] == "mail_unavailable"
    assert client.get(f"/v1/admin/inquiries/{iid}", headers=oh).json()["status"] == "new"
