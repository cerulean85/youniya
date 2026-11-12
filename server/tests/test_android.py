"""Android (기획서 24장): Google Play 코인 충전 and refunds, FCM devices and sending, Apple sign-in by the web flow."""

import json
from datetime import datetime, timedelta, timezone
from urllib.parse import parse_qs, urlparse

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient

from youniya_api import coins
from youniya_api.google_api import PlayPurchaseInvalid, PlayUnavailable
from youniya_api.models import AuthHandoff, CoinEntry, DeviceToken, User
from youniya_api.push import FcmClient, Message, Push
from youniya_api.routers.apple_handoff import s256

from .conftest import sign_in

SERVICES = "com.example.web"
CALLBACK = "https://api.example.com/v1/auth/apple/web/callback"
VERIFIER = "v" * 43
CHALLENGE = s256(VERIFIER)
FCM = "dGVzdC10b2tlbg:APA91bH" + "Ab-_" * 30


# --- Google Play -------------------------------------------------------------------------------------------

class FakePlay:
    def __init__(self, **purchase):
        self.purchase = {"purchaseState": 0, "consumptionState": 0, "orderId": "GPA.1111-2222-3333-44444",
                         **purchase}
        self.consumed, self.fail, self.voided_list = [], None, []

    def product_purchase(self, product_id, token):
        if self.fail:
            raise self.fail
        return dict(self.purchase)

    def consume(self, product_id, token):
        self.consumed.append((product_id, token))
        self.purchase["consumptionState"] = 1

    def voided(self, start_ms):
        return self.voided_list


def _play_app(make_app, play, **kw):
    app = make_app(**{"trust_purchases": False, **kw})
    app.state.play = play
    client = TestClient(app)
    h = sign_in(client)
    uid = client.get("/v1/me", headers=h).json()["id"]
    return app, client, h, uid


def _buy(client, h, token="tok-1", product="coin_110", **extra):
    return client.post("/v1/coins/purchases", json={"platform": "android", "product_id": product,
                                                   "purchase_token": token, **extra}, headers=h)


def test_play_purchase_is_granted_once_and_consumed(make_app):
    play = FakePlay()
    app, client, h, uid = _play_app(make_app, play)
    play.purchase["obfuscatedExternalAccountId"] = uid
    r = _buy(client, h)
    assert r.status_code == 200, r.text
    assert r.json() == {"coins": 110, "added": 110, "already_processed": False, "consumed": True}
    assert play.consumed == [("coin_110", "tok-1")]
    again = _buy(client, h).json()
    assert again["added"] == 0 and again["already_processed"] and again["consumed"] and again["coins"] == 110
    assert len(play.consumed) == 1
    items = client.get("/v1/coins/history", headers=h).json()["items"]
    assert items[0]["source"] == "google_play" and items[0]["kind"] == "purchase"


def test_play_purchase_refusals(make_app):
    play = FakePlay(obfuscatedExternalAccountId="someone-else")
    app, client, h, uid = _play_app(make_app, play)
    assert _buy(client, h).json()["error"]["code"] == "transaction_used"
    play.purchase.update(obfuscatedExternalAccountId=uid, purchaseState=2)
    r = _buy(client, h)
    assert r.status_code == 409 and r.json()["error"]["code"] == "purchase_pending"
    play.purchase["purchaseState"] = 1
    assert _buy(client, h).json()["error"]["code"] == "purchase_invalid"
    play.purchase["purchaseState"] = 0
    play.fail = PlayPurchaseInvalid("404")
    assert _buy(client, h).status_code == 422
    play.fail = PlayUnavailable("500")
    assert _buy(client, h).json()["error"]["code"] == "purchase_unverified"
    play.fail = None
    assert _buy(client, h, product="coin_999").json()["error"]["code"] == "unknown_product"
    assert client.get("/v1/coins", headers=h).json()["coins"] == 0


def test_play_test_purchase_follows_the_sandbox_setting(make_app):
    play = FakePlay(purchaseType=0)
    _, client, h, _ = _play_app(make_app, play, allow_sandbox_purchases=False)
    assert _buy(client, h).json()["error"]["code"] == "purchase_invalid"


def test_another_account_cannot_reuse_an_order(make_app):
    play = FakePlay()
    app, client, h, _ = _play_app(make_app, play)
    assert _buy(client, h).json()["added"] == 110
    other = sign_in(client, "user-2")
    assert _buy(client, other).json()["error"]["code"] == "transaction_used"


def test_play_unconfigured_refuses_unless_trusted(make_app):
    _, client, h, _ = _play_app(make_app, None)
    assert _buy(client, h).json()["error"]["code"] == "purchase_unverified"
    _, client, h, _ = _play_app(make_app, None, trust_purchases=True)
    r = client.post("/v1/coins/purchases", json={"platform": "android", "product_id": "coin_330",
                                                 "order_id": "GPA.dev-1"}, headers=h).json()
    assert r == {"coins": 330, "added": 330, "already_processed": False, "consumed": False}


def test_play_refund_takes_back_what_is_left_once(make_app):
    play = FakePlay()
    app, client, h, uid = _play_app(make_app, play)
    _buy(client, h, product="coin_330")
    with app.state.sessions() as db:
        user = db.get(User, uid)
        coins.spend(db, user, 300, "별 띄우기")
        db.commit()
        play.voided_list = [{"orderId": "GPA.1111-2222-3333-44444", "purchaseToken": "tok-1"},
                            {"orderId": "GPA.not-ours", "purchaseToken": "x"}]
        assert coins.take_back_play_voided(db, play) == 1
        assert coins.take_back_play_voided(db, play) == 0  # once
        assert db.get(User, uid).coins == 0
        refund = db.query(CoinEntry).filter(CoinEntry.transaction_id == "refund:gp:GPA.1111-2222-3333-44444").one()
        assert refund.delta == -30
    items = client.get("/v1/coins/history", headers=h).json()["items"]
    assert items[0]["kind"] == "refund" and items[0]["source"] == "google_play"


def test_cron_checks_play_refunds(make_app):
    play = FakePlay()
    app, client, h, uid = _play_app(make_app, play, cron_secret="cs")
    _buy(client, h)
    play.voided_list = [{"orderId": "GPA.1111-2222-3333-44444", "purchaseToken": "tok-1"}]
    r = client.get("/v1/cron/purge-purchase-records", headers={"Authorization": "Bearer cs"})
    assert r.json()["play_refunds"] == 1
    assert client.get("/v1/coins", headers=h).json()["coins"] == 0


# --- FCM ---------------------------------------------------------------------------------------------------

def test_android_devices_keep_the_token_as_given(make_app):
    app = make_app()
    client = TestClient(app)
    h = sign_in(client)
    assert client.put("/v1/me/devices", json={"platform": "android", "token": FCM}, headers=h).status_code == 204
    with app.state.sessions() as db:
        assert [(d.token, d.environment) for d in db.query(DeviceToken)] == [(FCM, "fcm")]
    assert client.put("/v1/me/devices", json={"platform": "android", "token": "no spaces allowed" * 3},
                      headers=h).status_code == 422
    # iOS is unchanged: hex and an environment.
    assert client.put("/v1/me/devices", json={"token": "a" * 64}, headers=h).status_code == 422
    assert client.put("/v1/me/devices", json={"token": FCM, "environment": "production"}, headers=h).status_code == 422
    assert client.delete(f"/v1/me/devices/{FCM}", headers=h).status_code == 204
    with app.state.sessions() as db:
        assert db.query(DeviceToken).count() == 0


class FakeSender:
    def __init__(self, result="sent"):
        self.sent, self.result = [], result

    def send_detail(self, token, environment, message):
        self.sent.append(token)
        return self.result, 200, ""


def test_push_routes_by_environment():
    apns, fcm = FakeSender(), FakeSender("gone")
    push = Push(apns, fcm)
    m = Message("t", "b", "notice")
    assert push.send("a" * 64, "production", m) == "sent" and apns.sent == ["a" * 64]
    assert push.send(FCM, "fcm", m) == "gone" and fcm.sent == [FCM]
    assert Push(apns, None).send(FCM, "fcm", m) == "failed"


def _service_account() -> dict:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption()).decode()
    return {"client_email": "push@youniya.iam.gserviceaccount.com", "private_key": pem, "private_key_id": "k1",
            "project_id": "youniya", "token_uri": "https://oauth2.googleapis.com/token"}


def test_fcm_client_sends_and_reads_errors():
    calls = []
    answers = iter([httpx.Response(200, json={"name": "projects/youniya/messages/1"}),
                    httpx.Response(404, json={"error": {"code": 404, "status": "NOT_FOUND", "message": "x",
                                                        "details": [{"errorCode": "UNREGISTERED"}]}}),
                    httpx.Response(503, json={"error": {"status": "UNAVAILABLE", "message": "later"}})])

    def handler(request: httpx.Request):
        calls.append(request)
        if request.url.host == "oauth2.googleapis.com":
            return httpx.Response(200, json={"access_token": "at", "expires_in": 3600})
        return next(answers)

    fcm = FcmClient(_service_account(), http=httpx.Client(transport=httpx.MockTransport(handler)))
    m = Message("제목", "본문", "report_result", {"screen": "star", "star_id": "s1"})
    assert fcm.send(FCM, "fcm", m) == "sent"
    sent = json.loads(calls[1].content)["message"]
    assert calls[1].url.path == "/v1/projects/youniya/messages:send"
    assert calls[1].headers["authorization"] == "Bearer at"
    assert sent["token"] == FCM and sent["data"]["kind"] == "report_result"
    assert json.loads(sent["data"]["target"]) == {"screen": "star", "star_id": "s1"}
    assert fcm.send(FCM, "fcm", m) == "gone"
    assert fcm.send(FCM, "fcm", m) == "failed"
    assert sum(c.url.host == "oauth2.googleapis.com" for c in calls) == 1  # the access token is reused


# --- Apple sign-in, web flow ------------------------------------------------------------------------------

class JwtVerifier:
    """Reads the test id_token without a signature; "bad" is refused."""

    def verify(self, provider, id_token):
        if id_token == "bad":
            raise jwt.InvalidTokenError("bad")
        return jwt.decode(id_token, options={"verify_signature": False})["sub"]


class FakeSiwa:
    def __init__(self):
        self.calls = []

    def revoke_with_code(self, code, client_id=None, redirect_uri=None, expected_sub=None):
        self.calls.append((code, client_id, redirect_uri, expected_sub))


def _apple_app(make_app, **kw):
    app = make_app(apple_services_id=SERVICES, apple_handoff_redirect_uri=CALLBACK,
                   apple_client_ids=("com.example.app", SERVICES), **kw)
    app.state.verifier = JwtVerifier()
    app.state.siwa = FakeSiwa()
    return app, TestClient(app)


def _start(client, purpose="signin"):
    r = client.get("/v1/auth/apple/web/start", params={"code_challenge": CHALLENGE, "purpose": purpose},
                   follow_redirects=False)
    assert r.status_code == 302, r.text
    q = {k: v[0] for k, v in parse_qs(urlparse(r.headers["location"]).query).items()}
    return q


def _id_token(sub, nonce, aud=SERVICES):
    return jwt.encode({"sub": sub, "aud": aud, "nonce": nonce}, "x" * 32, algorithm="HS256")


def _back(r) -> dict:
    """The deep link the callback page opens."""
    assert r.status_code == 200
    href = r.text.split('href="')[1].split('"')[0].replace("&amp;", "&")
    assert href.startswith("youniya://auth/apple?")
    return {k: v[0] for k, v in parse_qs(urlparse(href).query).items()}


def _callback(client, **form):
    return client.post("/v1/auth/apple/web/callback", data=form)


def test_web_flow_is_off_until_configured(make_app):
    client = TestClient(make_app())
    assert client.get("/v1/auth/apple/web/start", params={"code_challenge": CHALLENGE},
                      follow_redirects=False).status_code == 404


def test_android_apple_sign_in(make_app):
    app, client = _apple_app(make_app)
    q = _start(client)
    assert q["client_id"] == SERVICES and q["redirect_uri"] == CALLBACK and q["response_mode"] == "form_post"
    back = _back(_callback(client, state=q["state"], code="apple-code", id_token=_id_token("apple-sub", q["nonce"])))
    assert back["purpose"] == "signin" and "code" in back
    # Only the hash is kept.
    with app.state.sessions() as db:
        assert db.query(AuthHandoff).one().code_hash != back["code"]
    # The verifier is needed; a wrong one uses the code up.
    assert client.post("/v1/auth/apple/exchange", json={"code": back["code"], "code_verifier": "w" * 43}).status_code == 400
    assert client.post("/v1/auth/apple/exchange", json={"code": back["code"], "code_verifier": VERIFIER}).status_code == 400

    back = _back(_callback(client, state=q["state"], code="c", id_token=_id_token("apple-sub", q["nonce"])))
    r = client.post("/v1/auth/apple/exchange", json={"code": back["code"], "code_verifier": VERIFIER})
    assert r.status_code == 200 and r.json()["access_token"]
    # The same account as the native sign-in with that sub.
    native = client.post("/v1/auth/apple", json={"id_token": _id_token("apple-sub", "-")}).json()
    assert native["user_id"] == r.json()["user_id"]
    again = client.post("/v1/auth/apple/exchange", json={"code": back["code"], "code_verifier": VERIFIER})
    assert again.json()["error"]["code"] == "handoff_invalid"


def test_callback_refusals(make_app):
    app, client = _apple_app(make_app)
    q = _start(client)
    assert _back(_callback(client, state=q["state"], error="user_cancelled_authorize")) == {
        "error": "cancelled", "purpose": "signin"}
    assert _back(_callback(client, state="forged", id_token=_id_token("s", q["nonce"])))["error"] == "failed"
    assert _back(_callback(client, state=q["state"], id_token=_id_token("s", "other-nonce")))["error"] == "failed"
    assert _back(_callback(client, state=q["state"], id_token=_id_token("s", q["nonce"], aud="com.example.app")))[
        "error"] == "failed"
    assert _back(_callback(client, state=q["state"], id_token="bad"))["error"] == "failed"
    with app.state.sessions() as db:
        assert db.query(AuthHandoff).count() == 0


def test_handoff_expires(make_app):
    app, client = _apple_app(make_app)
    q = _start(client)
    back = _back(_callback(client, state=q["state"], id_token=_id_token("s", q["nonce"])))
    with app.state.sessions() as db:
        db.query(AuthHandoff).update({"expires_at": datetime.now(timezone.utc) - timedelta(seconds=1)})
        db.commit()
    assert client.post("/v1/auth/apple/exchange", json={"code": back["code"], "code_verifier": VERIFIER}).status_code == 400


def test_dev_name_skips_apple(make_app):
    app, client = _apple_app(make_app, dev_login=True)
    r = client.get("/v1/auth/apple/web/start", params={"code_challenge": CHALLENGE, "dev_name": "tester"})
    back = _back(r)
    tokens = client.post("/v1/auth/apple/exchange", json={"code": back["code"], "code_verifier": VERIFIER}).json()
    assert tokens["user_id"] == client.post("/v1/auth/dev", json={"name": "tester"}).json()["user_id"]
    # Without DEV_LOGIN the name is ignored and Apple is asked.
    _, plain = _apple_app(make_app)
    assert plain.get("/v1/auth/apple/web/start", params={"code_challenge": CHALLENGE, "dev_name": "tester"},
                     follow_redirects=False).status_code == 302


def test_android_account_deletion_revokes_with_the_web_code(make_app):
    app, client = _apple_app(make_app)
    tokens = client.post("/v1/auth/apple", json={"id_token": _id_token("apple-sub", "-")}).json()
    h = {"Authorization": f"Bearer {tokens['access_token']}"}

    q = _start(client, "delete")
    back = _back(_callback(client, state=q["state"], code="apple-code-1", id_token=_id_token("apple-sub", q["nonce"])))
    assert back["purpose"] == "delete"
    # A delete code does not sign anyone in.
    assert client.post("/v1/auth/apple/exchange", json={"code": back["code"], "code_verifier": VERIFIER}).status_code == 400

    q = _start(client, "delete")
    back = _back(_callback(client, state=q["state"], code="apple-code-2", id_token=_id_token("apple-sub", q["nonce"])))
    r = client.request("DELETE", "/v1/me", json={"apple_handoff_code": back["code"],
                                                 "apple_handoff_verifier": VERIFIER}, headers=h)
    assert r.status_code == 204
    assert app.state.siwa.calls == [("apple-code-2", SERVICES, CALLBACK, "apple-sub")]
    assert client.get("/v1/me", headers=h).status_code == 401


def test_deletion_handoff_of_another_apple_id_is_refused(make_app):
    app, client = _apple_app(make_app)
    tokens = client.post("/v1/auth/apple", json={"id_token": _id_token("apple-sub", "-")}).json()
    h = {"Authorization": f"Bearer {tokens['access_token']}"}
    q = _start(client, "delete")
    back = _back(_callback(client, state=q["state"], code="c", id_token=_id_token("someone-else", q["nonce"])))
    r = client.request("DELETE", "/v1/me", json={"apple_handoff_code": back["code"],
                                                 "apple_handoff_verifier": VERIFIER}, headers=h)
    assert r.status_code == 400 and r.json()["error"]["code"] == "apple_reauth_required"
    assert app.state.siwa.calls == [] and client.get("/v1/me", headers=h).status_code == 200
