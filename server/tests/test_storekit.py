import base64
import uuid
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID
from fastapi.testclient import TestClient

from youniya_api.storekit import INTERMEDIATE_OID, LEAF_OID, PurchaseInvalid, StoreKitVerifier, _apple_root

from .conftest import sign_in

BUNDLE = "com.youniya.app"


def _cert(name, key, issuer_name, issuer_key, oid=None, ca=False, days=365):
    now = datetime.now(timezone.utc)
    b = (x509.CertificateBuilder()
         .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name)]))
         .issuer_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, issuer_name)]))
         .public_key(key.public_key()).serial_number(x509.random_serial_number())
         .not_valid_before(now - timedelta(days=1)).not_valid_after(now + timedelta(days=days))
         .add_extension(x509.BasicConstraints(ca=ca, path_length=None), critical=True))
    if oid:
        b = b.add_extension(x509.UnrecognizedExtension(oid, b"\x05\x00"), critical=False)
    return b.sign(issuer_key, hashes.SHA256())


class FakeApple:
    """A root, intermediate and leaf shaped like Apple's StoreKit chain."""

    def __init__(self):
        self.root_key = ec.generate_private_key(ec.SECP384R1())
        self.inter_key = ec.generate_private_key(ec.SECP384R1())
        self.leaf_key = ec.generate_private_key(ec.SECP256R1())
        self.root = _cert("Root", self.root_key, "Root", self.root_key, ca=True)
        self.inter = _cert("WWDR", self.inter_key, "Root", self.root_key, INTERMEDIATE_OID, ca=True)
        self.leaf = _cert("StoreKit", self.leaf_key, "WWDR", self.inter_key, LEAF_OID)

    def jws(self, sign_with=None, chain=None, **overrides):
        payload = {"bundleId": BUNDLE, "productId": "coin_120", "transactionId": str(uuid.uuid4().int)[:16],
                   "quantity": 1, "type": "Consumable", "environment": "Production"} | overrides
        x5c = [base64.b64encode(c.public_bytes(serialization.Encoding.DER)).decode()
               for c in (chain or (self.leaf, self.inter, self.root))]
        return jwt.encode(payload, sign_with or self.leaf_key, algorithm="ES256", headers={"x5c": x5c})


@pytest.fixture
def apple():
    return FakeApple()


def test_bundled_root_is_apple_g3():
    assert _apple_root().subject.rfc4514_string().endswith("CN=Apple Root CA - G3")


def test_valid_transaction(apple):
    tx = StoreKitVerifier(BUNDLE, root=apple.root).verify(apple.jws())
    assert tx["productId"] == "coin_120"


@pytest.mark.parametrize("case", ["other_app", "forged_signature", "foreign_root", "missing_oid", "revoked",
                                  "subscription", "garbage"])
def test_rejected_transactions(apple, case):
    v = StoreKitVerifier(BUNDLE, root=apple.root)
    other = FakeApple()
    jws = {
        "other_app": lambda: apple.jws(bundleId="com.someone.else"),
        "forged_signature": lambda: apple.jws(sign_with=ec.generate_private_key(ec.SECP256R1())),
        "foreign_root": lambda: other.jws(),
        "missing_oid": lambda: apple.jws(chain=(_cert("StoreKit", apple.leaf_key, "WWDR", apple.inter_key),
                                                apple.inter, apple.root)),
        "revoked": lambda: apple.jws(revocationDate=1700000000000),
        "subscription": lambda: apple.jws(type="Auto-Renewable Subscription"),
        "garbage": lambda: "not.a.jws",
    }[case]()
    with pytest.raises(PurchaseInvalid):
        v.verify(jws)


def test_sandbox_can_be_refused(apple):
    assert StoreKitVerifier(BUNDLE, root=apple.root).verify(apple.jws(environment="Sandbox"))
    with pytest.raises(PurchaseInvalid):
        StoreKitVerifier(BUNDLE, allow_sandbox=False, root=apple.root).verify(apple.jws(environment="Sandbox"))


def test_purchase_endpoint(make_app, apple):
    app = make_app(trust_purchases=False, apple_bundle_id=BUNDLE)
    app.state.storekit = StoreKitVerifier(BUNDLE, root=apple.root)
    client = TestClient(app)
    h = sign_in(client)
    me = client.get("/v1/me", headers=h).json()["id"]

    jws = apple.jws(appAccountToken=me, quantity=2)
    r = client.post("/v1/coins/purchases", json={"signed_transaction": jws}, headers=h).json()
    assert r == {"coins": 240, "added": 240, "already_processed": False}
    # Sending the same transaction again adds nothing.
    assert client.post("/v1/coins/purchases", json={"signed_transaction": jws},
                       headers=h).json()["already_processed"] is True

    bad = client.post("/v1/coins/purchases", json={"signed_transaction": FakeApple().jws()}, headers=h)
    assert bad.status_code == 422 and bad.json()["error"]["code"] == "purchase_invalid"
    # Bought for another account.
    other = client.post("/v1/coins/purchases", json={"signed_transaction": apple.jws(appAccountToken=str(uuid.uuid4()))},
                        headers=h)
    assert other.status_code == 409
    # Without a signed transaction, and without TRUST_PURCHASES, nothing is added.
    dev = client.post("/v1/coins/purchases", json={"product_id": "coin_50", "transaction_id": "t"}, headers=h)
    assert dev.status_code == 503
    assert client.get("/v1/coins", headers=h).json()["coins"] == 240
