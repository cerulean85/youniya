"""Remote notifications: device tokens, 101 report results, opt-in announcements and the APNs client."""

from datetime import datetime, timezone

import httpx
import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient

from youniya_api.models import DeviceToken
from youniya_api.push import ApnsClient, Message, is_night_kst

from .conftest import float_star, sign_in

OP = {"X-Admin-Token": "op-token"}


def token(n: int) -> str:
    return f"{n:064x}"


class FakeApns:
    def __init__(self, gone=()):
        self.sent: list[tuple[str, str, Message]] = []
        self.gone = set(gone)

    def send(self, device_token, environment, message):
        return self.send_detail(device_token, environment, message)[0]

    def send_detail(self, device_token, environment, message):
        if device_token in self.gone:
            return "gone", 400, "BadDeviceToken"
        self.sent.append((device_token, environment, message))
        return "sent", 200, ""


def _app(make_app, apns=None):
    app = make_app(admin_token="op-token")
    app.state.push = apns
    return app, TestClient(app)


def _devices(app):
    with app.state.sessions() as db:
        return {d.token: (d.user_id, d.environment) for d in db.query(DeviceToken)}


def test_device_tokens_follow_the_last_sign_in(make_app):
    app, client = _app(make_app)
    a, b = sign_in(client, "a"), sign_in(client, "b")
    a_id, b_id = (client.get("/v1/me", headers=h).json()["id"] for h in (a, b))

    assert client.put("/v1/me/devices", json={"token": token(1).upper(), "environment": "sandbox"},
                      headers=a).status_code == 204
    assert _devices(app) == {token(1): (a_id, "sandbox")}
    # Same phone, someone else signs in: the device is theirs now.
    client.put("/v1/me/devices", json={"token": token(1), "environment": "production"}, headers=b)
    assert _devices(app) == {token(1): (b_id, "production")}
    # Only the owner can remove it.
    client.delete(f"/v1/me/devices/{token(1)}", headers=a)
    assert token(1) in _devices(app)
    client.delete(f"/v1/me/devices/{token(1)}", headers=b)
    assert _devices(app) == {}

    assert client.put("/v1/me/devices", json={"token": "not-hex", "environment": "sandbox"},
                      headers=a).status_code == 422
    client.put("/v1/me/devices", json={"token": token(2), "environment": "sandbox"}, headers=a)
    client.delete("/v1/me", headers=a)
    assert _devices(app) == {}  # account deletion takes its devices


def _reported_line(client, reporters):
    owner, writer = sign_in(client, "owner"), sign_in(client, "writer")
    ids = [float_star(client, owner)["id"] for _ in range(3)]
    n = client.post("/v1/nebulae", json={"name": "성운", "star_ids": ids}, headers=owner).json()
    share = client.put(f"/v1/nebulae/{n['id']}/share", json={}, headers=owner).json()
    line = client.post(f"/v1/plaza/nebulae/{share['share_id']}/lines", json={"text": "광고 보러 오세요"},
                       headers=writer).json()
    for h in reporters:
        client.post(f"/v1/plaza/lines/{line['id']}/report", json={"reason": "spam"}, headers=h)
    return line["id"]


def test_reporters_hear_the_outcome_once(make_app):
    apns = FakeApns(gone={token(3)})
    app, client = _app(make_app, apns)
    r1, r2 = sign_in(client, "r1"), sign_in(client, "r2")
    client.put("/v1/me/devices", json={"token": token(1), "environment": "production"}, headers=r1)
    client.put("/v1/me/devices", json={"token": token(2), "environment": "sandbox"}, headers=r2)
    client.put("/v1/me/devices", json={"token": token(3), "environment": "sandbox"}, headers=r2)  # uninstalled
    line_id = _reported_line(client, [r1, r2])

    r = client.post(f"/v1/admin/lines/{line_id}/hide", headers=OP).json()
    assert r["reporters_told"] == 2 and r["push"] == {"sent": 2, "gone": 1, "failed": 0, "devices": 3}
    assert {t for t, _, _ in apns.sent} == {token(1), token(2)}
    message = apns.sent[0][2]
    assert message.kind == "report_result" and "광고 보러" not in message.body  # the line is never quoted
    assert token(3) not in _devices(app)  # a dead token is forgotten

    # Restoring later does not tell the same reporters again.
    apns.sent.clear()
    assert client.post(f"/v1/admin/lines/{line_id}/restore", headers=OP).json()["reporters_told"] == 0
    assert apns.sent == []


def test_moderation_works_without_apns(make_app):
    _, client = _app(make_app, None)
    line_id = _reported_line(client, [sign_in(client, "r1")])
    r = client.post(f"/v1/admin/lines/{line_id}/restore", headers=OP).json()
    assert r["reporters_told"] == 1 and r["push"]["sent"] == 0


def test_announcements_reach_only_opted_in_users_by_day(make_app, monkeypatch):
    apns = FakeApns()
    _, client = _app(make_app, apns)
    yes, no = sign_in(client, "yes", consent=False), sign_in(client, "no")
    client.post("/v1/me/consent", json={"terms": True, "privacy": True, "sensitive": True, "marketing": True},
                headers=yes)
    for i, h in enumerate((yes, no)):
        client.put("/v1/me/devices", json={"token": token(i), "environment": "production"}, headers=h)
    body = {"title": "새 우주의 색", "body": "오로라 하늘이 생겼어요."}

    dry = client.post("/v1/admin/announcements", json=body, headers=OP).json()
    assert dry == {"recipients": 1, "title": "(광고) 새 우주의 색", "sent": None} and apns.sent == []

    monkeypatch.setattr("youniya_api.routers.admin.is_night_kst", lambda: True)
    r = client.post("/v1/admin/announcements", json=body | {"dry_run": False}, headers=OP)
    assert r.status_code == 409 and r.json()["error"]["code"] == "night_time"

    monkeypatch.setattr("youniya_api.routers.admin.is_night_kst", lambda: False)
    r = client.post("/v1/admin/announcements", json=body | {"dry_run": False}, headers=OP).json()
    assert r["sent"]["sent"] == 1 and [t for t, _, _ in apns.sent] == [token(0)]
    sent = apns.sent[0][2]
    assert sent.title.startswith("(광고)") and sent.body.endswith("수신거부: 설정 › 알림")


def test_night_is_kst():
    assert is_night_kst(datetime(2026, 11, 7, 12, 30, tzinfo=timezone.utc))  # 21:30 KST
    assert is_night_kst(datetime(2026, 11, 7, 22, 59, tzinfo=timezone.utc))  # 07:59 KST
    assert not is_night_kst(datetime(2026, 11, 7, 23, 0, tzinfo=timezone.utc))  # 08:00 KST
    assert not is_night_kst(datetime(2026, 11, 7, 11, 59, tzinfo=timezone.utc))  # 20:59 KST


def test_apns_client_request_and_results():
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption()).decode()
    seen = []

    def handler(request: httpx.Request):
        seen.append(request)
        tail = request.url.path.rsplit("/", 1)[1]
        if tail == token(2):
            return httpx.Response(410, json={"reason": "Unregistered"})
        if tail == token(3):
            return httpx.Response(500, json={"reason": "InternalServerError"})
        return httpx.Response(200)

    client = ApnsClient("TEAM123456", "KEY1234567", pem, "com.dycdyp.youniya")
    client._http = httpx.Client(transport=httpx.MockTransport(handler))
    m = Message("제목", "본문", "report_result")
    assert client.send(token(1), "production", m) == "sent"
    assert client.send(token(1), "sandbox", m) == "sent"
    assert client.send(token(2), "production", m) == "gone"
    assert client.send(token(3), "production", m) == "failed"

    first = seen[0]
    assert str(first.url) == f"https://api.push.apple.com/3/device/{token(1)}"
    assert str(seen[1].url).startswith("https://api.sandbox.push.apple.com/")
    assert first.headers["apns-topic"] == "com.dycdyp.youniya" and first.headers["apns-push-type"] == "alert"
    provider = first.headers["authorization"].removeprefix("bearer ")
    assert jwt.get_unverified_header(provider)["kid"] == "KEY1234567"
    assert jwt.decode(provider, key.public_key(), algorithms=["ES256"])["iss"] == "TEAM123456"
    assert seen[3].headers["authorization"] == first.headers["authorization"]  # reused, not renewed per push
    import json
    assert json.loads(first.content) == {"aps": {"alert": {"title": "제목", "body": "본문"}, "sound": "default"},
                                         "kind": "report_result"}


def test_operator_status_shows_what_is_set_up(make_app):
    app, client = _app(make_app, FakeApns())
    r = client.get("/v1/admin/status", headers=OP).json()
    assert r["push"] is True and r["storekit"] is False and r["trust_purchases"] is True
    assert r["error_reports"] is False
    assert client.get("/v1/admin/status").status_code == 404


def test_operator_test_push(make_app):
    apns = FakeApns(gone={token(2)})
    app, client = _app(make_app, apns)
    h = sign_in(client, "phone")
    user_id = client.get("/v1/me", headers=h).json()["id"]
    assert client.post("/v1/admin/push-test", json={"user_id": user_id}, headers=OP).json() == {"devices": []}

    client.put("/v1/me/devices", json={"token": token(1), "environment": "sandbox"}, headers=h)
    client.put("/v1/me/devices", json={"token": token(2), "environment": "production"}, headers=h)
    devices = client.post("/v1/admin/push-test", json={"user_id": user_id}, headers=OP).json()["devices"]
    by_env = {d["environment"]: d for d in devices}
    assert by_env["sandbox"]["result"] == "sent" and by_env["sandbox"]["token"] == token(1)[:8] + "…"
    assert by_env["production"] | {"registered_at": None} == {
        "token": token(2)[:8] + "…", "environment": "production", "registered_at": None,
        "result": "gone", "status": 400, "reason": "BadDeviceToken"}
    assert token(2) not in _devices(app) and apns.sent[0][2].kind == "test"

    assert client.post("/v1/admin/push-test", json={"user_id": "nobody"}, headers=OP).status_code == 404
    _, bare = _app(make_app, None)
    assert bare.post("/v1/admin/push-test", json={"user_id": user_id}, headers=OP).json()["error"]["code"] \
        == "push_not_configured"


def test_operator_error_test_is_a_500(make_app):
    app, _ = _app(make_app)
    client = TestClient(app, raise_server_exceptions=False)
    assert client.post("/v1/admin/error-test", headers=OP).status_code == 500
    assert client.post("/v1/admin/error-test").status_code == 404
