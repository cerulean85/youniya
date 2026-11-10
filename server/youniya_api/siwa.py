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

    def client_secret(self, client_id: str | None = None) -> str:
        now = int(time.time())
        claims = {"iss": self.team_id, "iat": now, "exp": now + 300, "aud": BASE, "sub": client_id or self.client_id}
        return jwt.encode(claims, self.key, algorithm="ES256", headers={"kid": self.key_id})

    def revoke_with_code(self, code: str, client_id: str | None = None, redirect_uri: str | None = None,
                         expected_sub: str | None = None) -> None:
        """`client_id`: the app's bundle id (default) or the web's Services ID, whichever the code was made for;
        a web code also needs the redirect_uri its sign-in used. Raises ReauthRequired when Apple refuses the
        code, or when the code belongs to another Apple ID than `expected_sub` (nothing is revoked then);
        httpx errors (network, Apple 5xx) pass through."""
        client_id = client_id or self.client_id
        secret = self.client_secret(client_id)
        data = {"grant_type": "authorization_code", "code": code, "client_id": client_id, "client_secret": secret}
        if redirect_uri:
            data["redirect_uri"] = redirect_uri
        r = httpx.post(f"{self.base}/auth/token", timeout=self.timeout, data=data)
        if r.status_code == 400:
            raise ReauthRequired(r.json().get("error", "invalid_request") if r.content else "invalid_request")
        r.raise_for_status()
        tokens = r.json()
        if expected_sub is not None:
            # Straight from Apple over TLS, so the id_token's claims are read without checking its signature.
            sub = jwt.decode(tokens.get("id_token", ""), options={"verify_signature": False}).get("sub") \
                if tokens.get("id_token") else None
            if sub != expected_sub:
                raise ReauthRequired("sub_mismatch")
        token, hint = ((tokens["refresh_token"], "refresh_token") if tokens.get("refresh_token")
                       else (tokens["access_token"], "access_token"))
        r = httpx.post(f"{self.base}/auth/revoke", timeout=self.timeout, data={
            "token": token, "token_type_hint": hint, "client_id": client_id, "client_secret": secret})
        r.raise_for_status()
