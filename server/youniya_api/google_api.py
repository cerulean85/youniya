"""Google APIs with a service account: Google Play Developer API (코인 충전, 환불) and FCM (안드로이드 알림).

A service account key is the JSON file Google Cloud hands out (IAM › Service accounts › Keys). The server signs
a JWT with it and trades that for an hour-long access token (OAuth 2.0 JWT bearer grant)."""

import base64
import hashlib
import json
import logging
import time
from pathlib import Path

import httpx
import jwt

log = logging.getLogger(__name__)

PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
PLAY_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"


def load_service_account(b64: str | None, path: str | None) -> dict | None:
    """The key JSON from a base64 line (Vercel has no files to read) or else a path. Wins: the base64."""
    if b64:
        return json.loads(base64.b64decode(b64))
    if path:
        return json.loads(Path(path).read_text())
    return None


class ServiceAccount:
    def __init__(self, info: dict, scope: str, http: httpx.Client | None = None):
        self.email, self.key = info["client_email"], info["private_key"]
        self.key_id, self.project_id = info.get("private_key_id"), info.get("project_id")
        self.token_uri = info.get("token_uri") or "https://oauth2.googleapis.com/token"
        self.scope = scope
        self.http = http or httpx.Client(timeout=15.0)
        self._token: tuple[str, float] | None = None

    def access_token(self) -> str:
        now = time.time()
        if self._token and self._token[1] - 60 > now:
            return self._token[0]
        assertion = jwt.encode({"iss": self.email, "scope": self.scope, "aud": self.token_uri,
                                "iat": int(now), "exp": int(now) + 3600}, self.key, algorithm="RS256",
                               headers={"kid": self.key_id} if self.key_id else None)
        r = self.http.post(self.token_uri, data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                                                 "assertion": assertion})
        r.raise_for_status()
        body = r.json()
        self._token = (body["access_token"], now + int(body.get("expires_in", 3600)))
        return self._token[0]

    def headers(self) -> dict:
        return {"authorization": f"Bearer {self.access_token()}"}


# --- Google Play: one-time products (coin_110 · coin_330 · coin_1100) ------------------------------------

class PlayPurchaseInvalid(Exception):
    """Google says the purchase token is not a purchase of this product in this app."""


class PlayUnavailable(Exception):
    """Google could not be asked (network, 5xx, our credentials). Nothing is granted; the app tries again."""


def play_transaction_id(order_id: str | None, purchase_token: str) -> str:
    """The coin entry's key: `gp:` + the order id, or a hash of the token for a purchase without one."""
    if order_id:
        return f"gp:{order_id}"
    return "gp:token:" + hashlib.sha256(purchase_token.encode()).hexdigest()[:48]


class PlayClient:
    def __init__(self, info: dict, package: str, http: httpx.Client | None = None):
        self.package = package
        self.account = ServiceAccount(info, PLAY_SCOPE, http)
        self.http = self.account.http

    def _call(self, method: str, url: str, **kw) -> httpx.Response:
        try:
            r = self.http.request(method, url, headers=self.account.headers(), **kw)
        except httpx.HTTPError as e:
            raise PlayUnavailable(type(e).__name__) from e
        if r.status_code in (400, 404, 410):
            raise PlayPurchaseInvalid(f"{r.status_code} {r.text[:200]}")
        if r.status_code >= 300:
            log.warning("google play %s %s: %s", method, r.status_code, r.text[:300])
            raise PlayUnavailable(str(r.status_code))
        return r

    def product_purchase(self, product_id: str, purchase_token: str) -> dict:
        """purchases.products.get: purchaseState (0 purchased · 1 cancelled · 2 pending), consumptionState,
        orderId, obfuscatedExternalAccountId, quantity, purchaseType (0: a license tester's test purchase)."""
        return self._call("GET", f"{PLAY_BASE}/{self.package}/purchases/products/{product_id}/tokens/{purchase_token}").json()

    def consume(self, product_id: str, purchase_token: str) -> None:
        """So the same coin package can be bought again. Also acknowledges it (Play refunds an unacknowledged
        purchase after 3 days)."""
        self._call("POST", f"{PLAY_BASE}/{self.package}/purchases/products/{product_id}/tokens/{purchase_token}:consume")

    def voided(self, start_ms: int) -> list[dict]:
        """purchases.voidedpurchases.list since `start_ms` (Google keeps 30 days): refunds, chargebacks and
        cancellations. Each has orderId, purchaseToken, voidedTimeMillis, voidedReason."""
        out, page = [], None
        while True:
            params = {"startTime": start_ms, "maxResults": 1000, "type": 0}
            if page:
                params["token"] = page
            body = self._call("GET", f"{PLAY_BASE}/{self.package}/purchases/voidedpurchases", params=params).json()
            out += body.get("voidedPurchases", [])
            page = (body.get("tokenPagination") or {}).get("nextPageToken")
            if not page:
                return out
