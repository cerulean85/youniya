"""14.3 새 기능·혜택 알림 수신 동의 (20261109)."""

from datetime import datetime, timedelta, timezone

from youniya_api import marketing
from youniya_api.models import AdminLog, User

from .conftest import sign_in


class FakePush:
    def __init__(self):
        self.sent = []

    def send(self, token, environment, message):
        self.sent.append(message)
        return "sent"


def _device(client, h):
    client.put("/v1/me/devices", json={"token": "a" * 64, "environment": "sandbox"}, headers=h)


def test_consent_is_recorded_and_told(client):
    push = FakePush()
    client.app.state.push = push
    h = sign_in(client)
    _device(client, h)
    m = client.get("/v1/me", headers=h).json()["marketing"]
    assert m["opt_in"] is False and m["consented_at"] is None
    r = client.put("/v1/me/marketing", json={"opt_in": True}, headers=h).json()
    assert r["opt_in"] and r["consented_at"] and r["reconfirm_due"] and r["changed"]
    assert push.sent[-1].title == "새 기능·혜택 알림 수신에 동의하셨어요" and push.sent[-1].kind == "consent_result"
    assert client.put("/v1/me/marketing", json={"opt_in": True}, headers=h).json()["changed"] is False
    r = client.put("/v1/me/marketing", json={"opt_in": False}, headers=h).json()
    assert r["opt_in"] is False and r["revoked_at"] and r["reconfirm_due"] is None
    assert push.sent[-1].title == "새 기능·혜택 알림 수신을 거부하셨어요" and len(push.sent) == 2


def test_two_yearly_reminder(client):
    push = FakePush()
    client.app.state.push = push
    h = sign_in(client)
    _device(client, h)
    client.put("/v1/me/marketing", json={"opt_in": True}, headers=h)
    with client.app.state.sessions() as db:
        assert marketing.remind_due(db, push) == 0
        u = db.query(User).one()
        u.marketing_consented_at = datetime.now(timezone.utc) - timedelta(days=731)
        db.commit()
        assert marketing.remind_due(db, push) == 1
        assert push.sent[-1].title == "새 기능·혜택 알림 수신 동의 안내"
        assert marketing.remind_due(db, push) == 0  # once per two years


def test_four_ads_a_month(make_app, monkeypatch):
    from fastapi.testclient import TestClient

    from youniya_api.routers import admin

    monkeypatch.setattr(admin, "is_night_kst", lambda: False)
    client = TestClient(make_app(admin_token="op-token"))
    op = {"X-Admin-Token": "op-token"}
    body = {"title": "새 별자리", "body": "12월의 황소자리가 열렸어요", "dry_run": False}
    for _ in range(4):
        assert client.post("/v1/admin/announcements", json=body, headers=op).status_code == 200
    r = client.post("/v1/admin/announcements", json=body, headers=op)
    assert r.status_code == 409 and r.json()["error"]["code"] == "monthly_limit"
    assert client.post("/v1/admin/announcements", json=body | {"dry_run": True}, headers=op).status_code == 200
