"""Encryption at rest, session tokens, and Apple / Google sign-in verification."""

import hashlib
import json
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from cryptography.fernet import Fernet

ACCESS_TTL = timedelta(hours=1)
REFRESH_TTL = timedelta(days=30)


class Cipher:
    """Writing and analysis are encrypted before they reach the database."""

    def __init__(self, key: str):
        self._f = Fernet(key.encode())

    def enc(self, text: str) -> str:
        return self._f.encrypt(text.encode()).decode()

    def dec(self, token: str) -> str:
        return self._f.decrypt(token.encode()).decode()

    def enc_json(self, value) -> str:
        return self.enc(json.dumps(value, ensure_ascii=False))

    def dec_json(self, token: str):
        return json.loads(self.dec(token))


def issue_access_token(user_id: str, secret: str) -> str:
    exp = datetime.now(timezone.utc) + ACCESS_TTL
    return jwt.encode({"sub": user_id, "exp": exp, "typ": "access"}, secret, algorithm="HS256")


def read_access_token(token: str, secret: str) -> str:
    """Returns the user id. Raises jwt.ExpiredSignatureError / jwt.InvalidTokenError."""
    claims = jwt.decode(token, secret, algorithms=["HS256"])
    if claims.get("typ") != "access":
        raise jwt.InvalidTokenError("not an access token")
    return claims["sub"]


def new_refresh_token() -> tuple[str, str]:
    """(token for the client, hash to store)"""
    token = secrets.token_urlsafe(32)
    return token, hash_token(token)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


class IdTokenVerifier:
    """Checks a Sign in with Apple / Google ID token and returns the account's `sub`."""

    PROVIDERS = {
        "apple": ("https://appleid.apple.com/auth/keys", ("https://appleid.apple.com",)),
        "google": (
            "https://www.googleapis.com/oauth2/v3/certs",
            ("https://accounts.google.com", "accounts.google.com"),
        ),
    }

    def __init__(self, audiences: dict[str, tuple[str, ...]]):
        self._audiences = audiences
        self._clients = {p: jwt.PyJWKClient(url) for p, (url, _) in self.PROVIDERS.items()}

    def verify(self, provider: str, id_token: str) -> str:
        audience = self._audiences.get(provider)
        if not audience:
            raise jwt.InvalidTokenError(f"{provider} sign-in is not configured")
        key = self._clients[provider].get_signing_key_from_jwt(id_token)
        claims = jwt.decode(
            id_token,
            key.key,
            algorithms=["RS256"],
            audience=list(audience),
            issuer=list(self.PROVIDERS[provider][1]),
        )
        return claims["sub"]
