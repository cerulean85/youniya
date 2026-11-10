"""Sign in with Apple token revocation on account deletion (App Review 5.1.1(v))."""

import httpx
import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient

from youniya_api.siwa import ReauthRequired, SiwaClient

from .conftest import sign_in


class FakeSiwa:
    def __init__(self, fail=None):
        self.codes, self.fail = [], fail

    def revoke_with_code(self, code, client_id=None, redirect_uri=None):
        self.codes.append(code)
        self.calls = getattr(self, "calls", []) + [(client_id, redirect_uri)]
        if self.fail:
            raise self.fail


def _client(make_app, siwa, **kw):
    app = make_app(**kw)
    app.state.siwa = siwa
    return TestClient(app)


def _gone(client, h) -> bool:
    return client.get("/v1/me", headers=h).status_code == 401


def test_apple_tokens_revoked_before_deletion(make_app):
    siwa = FakeSiwa()
    client = _client(make_app, siwa)
    h = sign_in(client)
    r = client.request("DELETE", "/v1/me", json={"apple_authorization_code": "c1"}, headers=h)
    assert r.status_code == 204 and siwa.codes == ["c1"] and _gone(client, h)


def test_refused_code_keeps_the_account(make_app):
    client = _client(make_app, FakeSiwa(ReauthRequired("invalid_grant")))
    h = sign_in(client)
    r = client.request("DELETE", "/v1/me", json={"apple_authorization_code": "old"}, headers=h)
    assert r.status_code == 400 and r.json()["error"]["code"] == "apple_reauth_required"
    assert client.get("/v1/me", headers=h).status_code == 200


def test_apple_unreachable_still_deletes(make_app):
    client = _client(make_app, FakeSiwa(httpx.ConnectError("down")))
    h = sign_in(client)
    assert client.request("DELETE", "/v1/me", json={"apple_authorization_code": "c"}, headers=h).status_code == 204
    assert _gone(client, h)


def test_without_code_or_key_as_before(make_app):
    siwa = FakeSiwa()
    client = _client(make_app, siwa)
    h = sign_in(client)
    assert client.delete("/v1/me", headers=h).status_code == 204 and siwa.codes == [] and _gone(client, h)
    client = _client(make_app, None)  # key not set: deleted, nothing revoked
    h = sign_in(client, sub="user-2")
    assert client.request("DELETE", "/v1/me", json={"apple_authorization_code": "c"}, headers=h).status_code == 204


def test_client_secret_and_calls(monkeypatch):
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption()).decode()
    c = SiwaClient("TEAM123456", "KEY1234567", pem, "com.example.app")
    claims = jwt.decode(c.client_secret(), key.public_key(), algorithms=["ES256"], audience="https://appleid.apple.com")
    assert claims["iss"] == "TEAM123456" and claims["sub"] == "com.example.app"
    assert jwt.get_unverified_header(c.client_secret())["kid"] == "KEY1234567"
    calls = []

    def post(url, data, timeout):
        calls.append((url, data))
        if url.endswith("/auth/token"):
            if data["code"] == "bad":
                return httpx.Response(400, json={"error": "invalid_grant"}, request=httpx.Request("POST", url))
            return httpx.Response(200, json={"access_token": "a", "refresh_token": "r"}, request=httpx.Request("POST", url))
        return httpx.Response(200, request=httpx.Request("POST", url))
    monkeypatch.setattr(httpx, "post", post)
    c.revoke_with_code("good")
    assert calls[0][1]["grant_type"] == "authorization_code" and calls[0][1]["client_id"] == "com.example.app"
    assert calls[1][0].endswith("/auth/revoke") and calls[1][1]["token"] == "r"
    assert calls[1][1]["token_type_hint"] == "refresh_token"
    try:
        c.revoke_with_code("bad")
        raise AssertionError("expected ReauthRequired")
    except ReauthRequired as e:
        assert str(e) == "invalid_grant"


def test_web_code_uses_its_services_id(make_app):
    siwa = FakeSiwa()
    client = _client(make_app, siwa, apple_bundle_id="com.example.app",
                     apple_client_ids=("com.example.app", "com.example.app.web"))
    h = sign_in(client)
    r = client.request("DELETE", "/v1/me", headers=h, json={"apple_authorization_code": "w",
                       "apple_client_id": "evil.client", "apple_redirect_uri": "https://example.com/cb"})
    assert r.status_code == 422 and r.json()["error"]["code"] == "unknown_apple_client" and siwa.codes == []
    r = client.request("DELETE", "/v1/me", headers=h, json={"apple_authorization_code": "w",
                       "apple_client_id": "com.example.app.web", "apple_redirect_uri": "https://example.com/cb"})
    assert r.status_code == 204 and siwa.calls == [("com.example.app.web", "https://example.com/cb")]


def test_web_client_secret_and_redirect(monkeypatch):
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption()).decode()
    c = SiwaClient("TEAM123456", "KEY1234567", pem, "com.example.app")
    sent = []
    monkeypatch.setattr(httpx, "post", lambda url, data, timeout: sent.append(data) or httpx.Response(
        200, json={"access_token": "a"}, request=httpx.Request("POST", url)))
    c.revoke_with_code("w", "com.example.app.web", "https://example.com/cb")
    assert sent[0]["client_id"] == "com.example.app.web" and sent[0]["redirect_uri"] == "https://example.com/cb"
    sub = jwt.decode(sent[0]["client_secret"], key.public_key(), algorithms=["ES256"],
                     audience="https://appleid.apple.com")["sub"]
    assert sub == "com.example.app.web" and sent[1]["token"] == "a" and sent[1]["token_type_hint"] == "access_token"
