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



def _spend(client, amount):
    """Coins spent on something (any feature): taken straight from the balance."""
    from youniya_api import coins
    from youniya_api.models import User
    with client.app.state.sessions() as db:
        u = db.query(User).first()
        assert coins.spend(db, u, amount, "별 띄우기")
        db.commit()

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
    _spend(client, 60)  # 60 of 120 spent

    r = client.post("/v1/storekit/notifications", json={"signedPayload": _request(apple, "500")}).json()
    assert r["handled"] is True
    assert appstore.sent == [("500", "Sandbox", {
        "customerConsented": True, "consumptionPercentage": 50000, "deliveryStatus": "DELIVERED",
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


def _purchase(coins, days_ago=1):
    return CoinEntry(delta=coins, created_at=datetime.now(timezone.utc) - timedelta(days=days_ago))


def test_refund_granted_only_if_the_balance_stays_at_zero_or_more():
    """Figma 46: 50 + 120 bought, 30 spent (balance 140): refunding the 120 leaves 20 → granted."""
    now = datetime.now(timezone.utc)
    assert consumption_info(_purchase(120), balance=140, now=now)["refundPreference"] == "GRANT_FULL"
    assert consumption_info(_purchase(120), balance=120, now=now)["refundPreference"] == "GRANT_FULL"
    declined = consumption_info(_purchase(120), balance=119, now=now)
    assert (declined["refundPreference"], declined["consumptionPercentage"]) == ("DECLINE", 833)
    assert consumption_info(_purchase(120, days_ago=8), balance=500, now=now)["refundPreference"] == "DECLINE"


def test_private_key_from_base64_or_path(tmp_path):
    import base64

    from youniya_api.config import Settings

    pem = ec.generate_private_key(ec.SECP256R1()).private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()
    path = tmp_path / "AuthKey.p8"
    path.write_text(pem)
    encoded = base64.b64encode(pem.encode()).decode()

    assert Settings(appstore_private_key_base64=encoded).appstore_private_key() == pem
    assert Settings(appstore_private_key_path=str(path)).appstore_private_key() == pem
    # Base64 wins when both are set, and line breaks pasted into the value are ignored.
    assert Settings(appstore_private_key_base64=encoded[:40] + "\n" + encoded[40:],
                    appstore_private_key_path="/nowhere").appstore_private_key() == pem
    assert Settings().appstore_private_key() is None
