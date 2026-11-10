"""Sign in with Apple token revocation on account deletion (App Review Guideline 5.1.1(v)).

The app sends the authorization code it just got from Apple; the server trades it for a token
(POST /auth/token) and revokes that token (POST /auth/revoke), both signed with a client secret: an
ES256 JWT made with the Sign in with Apple key (Apple Developer › Keys, with Sign in with Apple)."""

import time

import httpx
import jwt

BASE = "https://appleid.apple.com"


class ReauthRequired(Exception):
    """Apple refused the code (invalid_grant): it is wrong, used or expired. The app gets a new one."""


class SiwaClient:
    def __init__(self, team_id: str, key_id: str, private_key_pem: str, client_id: str, base: str = BASE,
                 timeout: float = 15):
        self.team_id, self.key_id, self.key, self.client_id = team_id, key_id, private_key_pem, client_id
        self.base, self.timeout = base, timeout

    def client_secret(self) -> str:
        now = int(time.time())
        claims = {"iss": self.team_id, "iat": now, "exp": now + 300, "aud": BASE, "sub": self.client_id}
        return jwt.encode(claims, self.key, algorithm="ES256", headers={"kid": self.key_id})

    def revoke_with_code(self, code: str) -> None:
        """Raises ReauthRequired when Apple refuses the code; httpx errors (network, Apple 5xx) pass through."""
        secret = self.client_secret()
        r = httpx.post(f"{self.base}/auth/token", timeout=self.timeout, data={
            "grant_type": "authorization_code", "code": code, "client_id": self.client_id, "client_secret": secret})
        if r.status_code == 400:
            raise ReauthRequired(r.json().get("error", "invalid_request") if r.content else "invalid_request")
        r.raise_for_status()
        tokens = r.json()
        token, hint = ((tokens["refresh_token"], "refresh_token") if tokens.get("refresh_token")
                       else (tokens["access_token"], "access_token"))
        r = httpx.post(f"{self.base}/auth/revoke", timeout=self.timeout, data={
            "token": token, "token_type_hint": hint, "client_id": self.client_id, "client_secret": secret})
        r.raise_for_status()
