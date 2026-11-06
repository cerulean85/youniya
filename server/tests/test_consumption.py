"""CONSUMPTION_REQUEST: spent coins are not refunded (Figma 46, user decision)."""

from datetime import datetime, timedelta, timezone

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient

from youniya_api.models import CoinEntry
from youniya_api.routers.coins import consumption_info
from youniya_api.storekit import AppStoreClient, StoreKitVerifier

from .conftest import float_star, sign_in
from .test_storekit import BUNDLE, FakeApple


class FakeAppStore:
    def __init__(self, fail=False):
        self.sent, self.fail = [], fail

    def send_consumption(self, transaction_id, environment, body):
        if self.fail:
            raise RuntimeError("apple down")
        self.sent.append((transaction_id, environment, body))


def _setup(make_app, appstore):
    apple = FakeApple()
    app = make_app(trust_purchases=False, apple_bundle_id=BUNDLE)
    app.state.storekit = StoreKitVerifier(BUNDLE, root=apple.root)
    app.state.appstore = appstore
    client = TestClient(app)
    return apple, client, sign_in(client)


def _request(apple, transaction_id):
    tx = apple.jws(transactionId=transaction_id)
    return apple.sign({"notificationType": "CONSUMPTION_REQUEST",
                       "data": {"bundleId": BUNDLE, "environment": "Sandbox", "signedTransactionInfo": tx}})


def _buy(client, h, apple, transaction_id, consent=True):
    r = client.post("/v1/coins/purchases", json={"signed_transaction": apple.jws(transactionId=transaction_id),
                                                 "consumption_consent": consent}, headers=h)
    assert r.status_code == 200, r.text


def test_spent_coins_ask_apple_to_decline(make_app):
    appstore = FakeAppStore()
    apple, client, h = _setup(make_app, appstore)
    _buy(client, h, apple, "500")
    float_star(client, h)
    client.post("/v1/telescope/reports", json={}, headers=h)  # free
    for _ in range(3):
        client.post("/v1/telescope/reports", json={}, headers=h)  # 90 of 120 spent

    r = client.post("/v1/storekit/notifications", json={"signedPayload": _request(apple, "500")}).json()
    assert r["handled"] is True
    assert appstore.sent == [("500", "Sandbox", {
        "customerConsented": True, "consumptionPercentage": 75000, "deliveryStatus": "DELIVERED",
        "refundPreference": "DECLINE", "sampleContentProvided": False})]


def test_unspent_within_a_week_may_be_refunded(make_app):
    appstore = FakeAppStore()
    apple, client, h = _setup(make_app, appstore)
    _buy(client, h, apple, "501")
    client.post("/v1/storekit/notifications", json={"signedPayload": _request(apple, "501")})
    body = appstore.sent[0][2]
    assert (body["consumptionPercentage"], body["refundPreference"]) == (0, "GRANT_FULL")


def test_without_consent_nothing_is_sent(make_app):
    appstore = FakeAppStore()
    apple, client, h = _setup(make_app, appstore)
    _buy(client, h, apple, "502", consent=False)
    r = client.post("/v1/storekit/notifications", json={"signedPayload": _request(apple, "502")}).json()
    assert r == {"handled": False, "reason": "no_consent"} and appstore.sent == []


def test_failed_send_asks_apple_to_retry(make_app):
    apple, client, h = _setup(make_app, FakeAppStore(fail=True))
    _buy(client, h, apple, "503")
    r = client.post("/v1/storekit/notifications", json={"signedPayload": _request(apple, "503")})
    assert r.status_code == 502


def test_unspent_after_a_week_is_declined():
    purchase = CoinEntry(delta=120, created_at=datetime.now(timezone.utc) - timedelta(days=8))
    info = consumption_info(purchase, balance=120, now=datetime.now(timezone.utc))
    assert (info["consumptionPercentage"], info["refundPreference"]) == (0, "DECLINE")


def test_api_token_claims():
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption()).decode()
    token = AppStoreClient("issuer-1", "KEY123", pem, BUNDLE)._token()
    assert jwt.get_unverified_header(token) == {"alg": "ES256", "kid": "KEY123", "typ": "JWT"}
    claims = jwt.decode(token, key.public_key(), algorithms=["ES256"], audience="appstoreconnect-v1")
    assert claims["iss"] == "issuer-1" and claims["bid"] == BUNDLE and claims["exp"] - claims["iat"] <= 3600
