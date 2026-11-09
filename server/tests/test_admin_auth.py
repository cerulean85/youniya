"""관리자 콘솔 인증 (18장, step 7): invitation, password + TOTP, lock, roles, audit."""

import time

from fastapi.testclient import TestClient

from youniya_api import operators as ops

TOKEN = {"X-Admin-Token": "op-token"}


def _app(make_app):
    return TestClient(make_app(admin_token="op-token"))


def _operator(client, email="owner@youniya.app", role="owner", headers=TOKEN):
    r = client.post("/v1/admin/operators/invite", json={"email": email, "role": role, "reason": "출시 준비"},
                    headers=headers)
    assert r.status_code == 201, r.text
    invite = r.json()["setup_token"]
    secret = client.post("/v1/admin/auth/setup", json={"invite_token": invite, "password": "correct horse 42"}).json()
    code = ops.totp_at(secret["totp_secret"], ops.totp_step())
    assert client.post("/v1/admin/auth/setup/confirm", json={"invite_token": invite, "code": code}).status_code == 200
    assert client.post("/v1/admin/auth/setup", json={"invite_token": invite, "password": "x" * 12}).status_code == 404
    return secret["totp_secret"]


def _sign_in(client, secret, email="owner@youniya.app", step_shift=1):
    """The setup used this step's code; the next step's is still accepted (clock drift)."""
    ch = client.post("/v1/admin/auth/login", json={"email": email, "password": "correct horse 42"}).json()["challenge"]
    r = client.post("/v1/admin/auth/totp", json={"challenge": ch, "code": ops.totp_at(secret, ops.totp_step() + step_shift)})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}, r.json()


def test_totp_matches_rfc6238():
    # RFC 6238 appendix B, SHA-1 secret "12345678901234567890" at T=59 → 94287082 (last 6: 287082)
    import base64
    secret = base64.b32encode(b"12345678901234567890").decode().rstrip("=")
    assert ops.totp_at(secret, 59 // 30) == "287082"
    assert ops.check_totp(secret, "287082", None, at=59) == 1 and ops.check_totp(secret, "287082", 1, at=59) is None


def test_invite_sign_in_and_use(make_app):
    client = _app(make_app)
    secret = _operator(client)
    h, body = _sign_in(client, secret)
    assert body["operator"]["role"] == "owner" and body["operator"]["totp"] is True
    assert client.get("/v1/admin/auth/me", headers=h).json()["email"] == "owner@youniya.app"
    assert client.get("/v1/admin/status", headers=h).status_code == 200
    # A code works once.
    ch = client.post("/v1/admin/auth/login", json={"email": "owner@youniya.app", "password": "correct horse 42"}).json()
    again = client.post("/v1/admin/auth/totp", json={"challenge": ch["challenge"], "code": ops.totp_at(secret, ops.totp_step())})
    assert again.status_code == 401 and again.json()["error"]["code"] == "invalid_code"
    client.post("/v1/admin/auth/logout", headers=h)
    assert client.get("/v1/admin/status", headers=h).status_code == 401
    # No credentials at all: the same 404 as an unknown path.
    assert client.get("/v1/admin/status").status_code == 404


def test_five_failures_lock_for_fifteen_minutes(make_app):
    client = _app(make_app)
    secret = _operator(client)
    for i in range(4):
        r = client.post("/v1/admin/auth/login", json={"email": "owner@youniya.app", "password": "wrong password!"})
        assert r.status_code == 401 and r.json()["error"]["code"] == "invalid_credentials"
    r = client.post("/v1/admin/auth/login", json={"email": "owner@youniya.app", "password": "wrong password!"})
    assert r.status_code == 423 and r.json()["error"]["until"]
    r = client.post("/v1/admin/auth/login", json={"email": "owner@youniya.app", "password": "correct horse 42"})
    assert r.status_code == 423  # even the right password, while locked
    unknown = client.post("/v1/admin/auth/login", json={"email": "nobody@youniya.app", "password": "x"})
    assert unknown.status_code == 401 and secret


def test_roles_and_the_last_owner(make_app):
    client = _app(make_app)
    owner_secret = _operator(client)
    oh, _ = _sign_in(client, owner_secret)
    mod_secret = _operator(client, "mod@youniya.app", "moderator", oh)
    mh, _ = _sign_in(client, mod_secret, "mod@youniya.app")
    assert client.get("/v1/admin/reports", headers=mh).status_code == 200
    denied = client.get("/v1/admin/status", headers=mh)
    assert denied.status_code == 403 and denied.json()["error"]["code"] == "forbidden_role"
    assert client.get("/v1/admin/operators", headers=mh).status_code == 403
    me = client.get("/v1/admin/auth/me", headers=oh).json()
    last = client.patch(f"/v1/admin/operators/{me['id']}", json={"role": "moderator", "reason": "x"}, headers=oh)
    assert last.status_code == 409 and last.json()["error"]["code"] == "last_owner"
    mod = next(o for o in client.get("/v1/admin/operators", headers=oh).json()["items"] if o["email"] == "mod@youniya.app")
    client.patch(f"/v1/admin/operators/{mod['id']}", json={"status": "disabled", "reason": "퇴사"}, headers=oh)
    assert client.get("/v1/admin/reports", headers=mh).status_code == 401  # sessions end with the account
    assert client.post("/v1/admin/operators/invite", json={"email": "x@y.z", "role": "owner"}, headers=oh).status_code == 422


def test_audit_keeps_who_did_what_and_why(make_app):
    client = _app(make_app)
    secret = _operator(client)
    h, _ = _sign_in(client, secret)
    items = client.get("/v1/admin/audit", headers=h).json()["items"]
    actions = [i["action"] for i in items]
    assert actions[:3] == ["sign_in", "operator_activated", "operator_invite"]
    assert items[-1]["reason"] == "출시 준비" and items[-1]["operator"] == "admin-token"
    csv = client.get("/v1/admin/audit", params={"format": "csv"}, headers=h)
    assert csv.status_code == 200 and "operator_invite" in csv.text and "출시 준비" in csv.text
    assert not any(r.path.startswith("/v1/admin/audit") and m in ("DELETE", "PATCH", "PUT")
                   for r in client.app.routes for m in getattr(r, "methods", []))
