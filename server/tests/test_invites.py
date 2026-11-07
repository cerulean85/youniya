"""초대 계정 (App Review): operator-made, argon2 only, same answer for a wrong login or password."""

from fastapi.testclient import TestClient

from youniya_api import invites
from youniya_api.models import InviteAccount


def test_invite_sign_in(make_app):
    app = make_app(invite_login=True)
    client = TestClient(app)
    with app.state.sessions() as db:
        user, password = invites.create(db, "Reviewer")
        stored = db.get(InviteAccount, "reviewer").password_hash
    assert stored.startswith("$argon2id$") and password not in stored

    r = client.post("/v1/auth/invite", json={"login": "reviewer", "password": password})
    assert r.status_code == 200 and r.json()["user_id"] == user.id and r.json()["needs_consent"] is True
    me = client.get("/v1/me", headers={"Authorization": f"Bearer {r.json()['access_token']}"})
    assert me.status_code == 200

    wrong_password = client.post("/v1/auth/invite", json={"login": "reviewer", "password": "x"})
    no_account = client.post("/v1/auth/invite", json={"login": "nobody", "password": "x"})
    assert wrong_password.status_code == no_account.status_code == 401
    assert wrong_password.json() == no_account.json()
    assert wrong_password.json()["error"]["code"] == "invalid_credentials"


def test_invite_sign_in_is_limited_and_can_be_off(make_app):
    assert TestClient(make_app()).post("/v1/auth/invite", json={"login": "a", "password": "b"}).status_code == 404
    client = TestClient(make_app(invite_login=True))
    codes = [client.post("/v1/auth/invite", json={"login": "a", "password": "b"}).status_code for _ in range(11)]
    assert codes == [401] * 9 + [429, 429]  # 10 a minute per IP, the 404 above counted
