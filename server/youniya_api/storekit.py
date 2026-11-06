"""StoreKit 2 signed transaction verification (`Transaction.jwsRepresentation`).

The JWS header carries the certificate chain [leaf, Apple WWDR intermediate, Apple Root CA - G3].
The chain must end in Apple's root (pinned below), each certificate must be signed by the next
and be in date, the Apple purpose OIDs must be present, and the leaf must sign the payload."""

import base64
from datetime import datetime, timezone
from pathlib import Path

import jwt
from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec

# SHA-256 of https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
APPLE_ROOT_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179"
LEAF_OID = x509.ObjectIdentifier("1.2.840.113635.100.6.11.1")
INTERMEDIATE_OID = x509.ObjectIdentifier("1.2.840.113635.100.6.2.1")


class PurchaseInvalid(Exception):
    pass


def _apple_root() -> x509.Certificate:
    cert = x509.load_der_x509_certificate((Path(__file__).parent / "certs" / "AppleRootCA-G3.cer").read_bytes())
    if cert.fingerprint(hashes.SHA256()).hex() != APPLE_ROOT_G3_SHA256:
        raise RuntimeError("certs/AppleRootCA-G3.cer is not Apple Root CA - G3")
    return cert


class StoreKitVerifier:
    def __init__(self, bundle_id: str, allow_sandbox: bool = True, root: x509.Certificate | None = None):
        self.bundle_id = bundle_id
        # App Review and TestFlight buy in the sandbox, so production builds must accept it.
        self.allow_sandbox = allow_sandbox
        self.root = root or _apple_root()

    def verify_signed(self, jws: str) -> dict:
        """Any App Store JWS (transaction or server notification): chain and signature only."""
        try:
            header = jwt.get_unverified_header(jws)
            if header.get("alg") != "ES256" or len(header.get("x5c", [])) != 3:
                raise PurchaseInvalid("unexpected header")
            leaf, intermediate, root = (x509.load_der_x509_certificate(base64.b64decode(c)) for c in header["x5c"])
            if root.fingerprint(hashes.SHA256()) != self.root.fingerprint(hashes.SHA256()):
                raise PurchaseInvalid("chain does not end in the Apple root")
            now = datetime.now(timezone.utc)
            for cert, issuer in ((leaf, intermediate), (intermediate, root)):
                if cert.issuer != issuer.subject or not cert.not_valid_before_utc <= now <= cert.not_valid_after_utc:
                    raise PurchaseInvalid("broken or expired chain")
                issuer.public_key().verify(cert.signature, cert.tbs_certificate_bytes,
                                           ec.ECDSA(cert.signature_hash_algorithm))
            leaf.extensions.get_extension_for_oid(LEAF_OID)
            intermediate.extensions.get_extension_for_oid(INTERMEDIATE_OID)
            return jwt.decode(jws, leaf.public_key(), algorithms=["ES256"])
        except PurchaseInvalid:
            raise
        except (jwt.InvalidTokenError, InvalidSignature, x509.ExtensionNotFound, ValueError, TypeError, KeyError) as e:
            raise PurchaseInvalid(str(e) or type(e).__name__) from e

    def verify_transaction(self, jws: str) -> dict:
        """A purchase to pay out: signed, this app's, not refunded, a consumable."""
        payload = self.verify_signed(jws)

        if payload.get("bundleId") != self.bundle_id:
            raise PurchaseInvalid("another app's transaction")
        if payload.get("environment") == "Sandbox" and not self.allow_sandbox:
            raise PurchaseInvalid("sandbox transaction")
        if payload.get("revocationDate"):
            raise PurchaseInvalid("refunded or revoked")
        if payload.get("type") != "Consumable":
            raise PurchaseInvalid("not a consumable")
        return payload


class AppStoreClient:
    """App Store Server API calls signed with the In-App Purchase key (ES256 JWT, ≤ 60 minutes)."""

    BASE = {"Production": "https://api.storekit.apple.com", "Sandbox": "https://api.storekit-sandbox.apple.com"}

    def __init__(self, issuer_id: str, key_id: str, private_key_pem: str, bundle_id: str):
        self.issuer_id, self.key_id, self.key, self.bundle_id = issuer_id, key_id, private_key_pem, bundle_id

    def _token(self) -> str:
        now = int(datetime.now(timezone.utc).timestamp())
        claims = {"iss": self.issuer_id, "iat": now, "exp": now + 300, "aud": "appstoreconnect-v1",
                  "bid": self.bundle_id}
        return jwt.encode(claims, self.key, algorithm="ES256", headers={"kid": self.key_id, "typ": "JWT"})

    def send_consumption(self, transaction_id: str, environment: str, body: dict) -> None:
        """Send Consumption Information V2. Raises unless Apple answers 202."""
        import httpx

        url = f"{self.BASE[environment]}/inApps/v2/transactions/consumption/{transaction_id}"
        resp = httpx.put(url, json=body, headers={"Authorization": f"Bearer {self._token()}"}, timeout=30)
        if resp.status_code != 202:
            raise RuntimeError(f"consumption info rejected: {resp.status_code} {resp.text[:200]}")
