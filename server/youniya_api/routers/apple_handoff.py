"""안드로이드 Apple 로그인 (기획서 24장 AN-02-1): Sign in with Apple's web flow in a Custom Tab, back to the app
through a one-time code.

1. The app makes a PKCE pair (code_verifier: 43-128 characters; code_challenge = base64url(sha256(verifier)),
   no padding) and opens GET /v1/auth/apple/web/start?purpose=signin&code_challenge=… in a Custom Tab.
2. The server sends the tab to Apple (Services ID APPLE_SERVICES_ID, state and nonce signed by the server).
3. Apple posts to POST /v1/auth/apple/web/callback. The server checks the state, the id_token and its nonce,
   keeps what the app needs behind a one-time code (2 minutes, once; only its hash is stored) and sends the tab
   to the app: APPLE_HANDOFF_RETURN?code=…&purpose=… (or ?error=cancelled|failed&purpose=…).
4. signin: the app trades the code and its code_verifier for a session at POST /v1/auth/apple/exchange.
   delete (계정 삭제의 Apple 다시 인증, 6장): the app sends both to DELETE /v1/me as apple_handoff_code and
   apple_handoff_verifier; the server revokes the Apple tokens with Apple's code, then deletes.

The id_token never goes into a URL, and a code caught by another app is useless without the verifier."""

import base64
import hashlib
import hmac
import html
import secrets
import time
from datetime import datetime, timedelta, timezone
from typing import Literal
from urllib.parse import parse_qs, urlencode

import jwt
from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import BaseModel, Field
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from ..deps import ApiError, get_db
from ..models import AuthHandoff
from ..ratelimit import per_ip
from ..security import Cipher
from ..views import aware
from .auth import _session_for

router = APIRouter(prefix="/v1/auth/apple", tags=["auth"])

HANDOFF_TTL = timedelta(minutes=2)
STATE_TTL = 600  # seconds the person has at Apple's page
STATE_AUD = "apple-handoff"
CHALLENGE = r"^[A-Za-z0-9_-]{43}$"


def _configured(request: Request) -> bool:
    s = request.app.state.settings
    return bool(s.apple_services_id and s.apple_handoff_redirect_uri)


def s256(verifier: str) -> str:
    return base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()


def _hash(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


def _new_handoff(db: Session, purpose: str, provider: str, sub: str, challenge: str,
                 apple_code_enc: str | None = None) -> str:
    code = secrets.token_urlsafe(32)
    db.add(AuthHandoff(code_hash=_hash(code), purpose=purpose, provider=provider, sub=sub, challenge=challenge,
                       apple_code_enc=apple_code_enc, expires_at=datetime.now(timezone.utc) + HANDOFF_TTL))
    db.commit()
    return code


def take_handoff(db: Session, code: str, verifier: str, purpose: str) -> AuthHandoff | None:
    """The handoff behind `code`, used up now; None if it is unknown, used, expired, for another purpose, or
    the verifier doesn't match (the code is used up then too)."""
    row = db.get(AuthHandoff, _hash(code))
    if row is None or row.used_at is not None:
        return None
    now = datetime.now(timezone.utc)
    taken = db.execute(update(AuthHandoff).where(AuthHandoff.code_hash == row.code_hash,
                                                 AuthHandoff.used_at.is_(None)).values(used_at=now)).rowcount
    db.commit()
    if not taken or aware(row.expires_at) < now or row.purpose != purpose:
        return None
    if not hmac.compare_digest(s256(verifier), row.challenge):
        return None
    return row


def _back_to_app(request: Request, **params) -> HTMLResponse:
    """A small page that opens the app. A redirect to a custom scheme after a cross-site form post is not
    always followed, so the page navigates itself and also offers a button."""
    url = f"{request.app.state.settings.apple_handoff_return}?{urlencode(params)}"
    safe = html.escape(url, quote=True)
    body = f"""<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>YOUNIYA</title>
<style>body{{font-family:system-ui,sans-serif;background:#0b0d1a;color:#e8e9f3;display:flex;min-height:100vh;
align-items:center;justify-content:center;margin:0;padding:16px;text-align:center}}
a{{display:inline-block;margin-top:16px;padding:12px 20px;border-radius:12px;background:#f2d27a;color:#0b0d1a;
text-decoration:none;font-weight:600}}</style></head>
<body><div><p>YOUNIYA 앱으로 돌아가고 있어요.</p><a id="go" href="{safe}">앱으로 돌아가기</a></div>
<script>location.replace(document.getElementById("go").href)</script></body></html>"""
    return HTMLResponse(body, headers={"Cache-Control": "no-store", "Referrer-Policy": "no-referrer",
                                       "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; "
                                                                  "script-src 'unsafe-inline'"})


@router.get("/web/start", dependencies=[per_ip("auth", 30, 60)], response_class=RedirectResponse)
def start(request: Request, code_challenge: str = Query(..., pattern=CHALLENGE),
          code_challenge_method: Literal["S256"] = "S256",
          purpose: Literal["signin", "delete"] = "signin",
          dev_name: str | None = Query(None, min_length=1, max_length=64), db: Session = Depends(get_db)):
    """Opens in the app's Custom Tab. Sends it on to Apple. With DEV_LOGIN, `dev_name` skips Apple and goes
    straight back to the app as dev account `dev_name` (signin only), to try the deep link and the exchange."""
    s = request.app.state.settings
    if dev_name is not None and s.dev_login and purpose == "signin":
        return _back_to_app(request, code=_new_handoff(db, "signin", "dev", dev_name, code_challenge), purpose="signin")
    if not _configured(request):
        raise ApiError(404, "not_found", "찾지 못했어요.")
    nonce = secrets.token_urlsafe(16)
    state = jwt.encode({"aud": STATE_AUD, "p": purpose, "c": code_challenge, "n": nonce,
                        "exp": int(time.time()) + STATE_TTL}, s.jwt_secret, algorithm="HS256")
    query = urlencode({"client_id": s.apple_services_id, "redirect_uri": s.apple_handoff_redirect_uri,
                       "response_type": "code id_token", "response_mode": "form_post", "state": state,
                       "nonce": nonce})
    return RedirectResponse(f"https://appleid.apple.com/auth/authorize?{query}", status_code=302)


async def apple_form(request: Request) -> dict:
    """Apple's form post (application/x-www-form-urlencoded): state, code, id_token, or error."""
    body = await request.body()
    if len(body) > 20000:
        return {}
    return {k: v[0] for k, v in parse_qs(body.decode("utf-8", "replace")).items()}


@router.post("/web/callback", dependencies=[per_ip("auth", 30, 60)], response_class=HTMLResponse)
def callback(request: Request, form: dict = Depends(apple_form), db: Session = Depends(get_db)):
    s = request.app.state.settings
    if not _configured(request):
        raise ApiError(404, "not_found", "찾지 못했어요.")
    try:
        state = jwt.decode(form.get("state", ""), s.jwt_secret, algorithms=["HS256"], audience=STATE_AUD)
    except jwt.InvalidTokenError:
        return _back_to_app(request, error="failed")
    purpose = state["p"]
    if form.get("error"):  # user_cancelled_authorize: the person closed Apple's page
        return _back_to_app(request, error="cancelled", purpose=purpose)
    id_token, apple_code = form.get("id_token", ""), form.get("code", "")
    try:
        sub = request.app.state.verifier.verify("apple", id_token)
        claims = jwt.decode(id_token, options={"verify_signature": False})  # checked just above
    except (jwt.InvalidTokenError, jwt.PyJWKClientError):
        return _back_to_app(request, error="failed", purpose=purpose)
    aud = claims.get("aud")
    if aud != s.apple_services_id and s.apple_services_id not in (aud if isinstance(aud, list) else []):
        return _back_to_app(request, error="failed", purpose=purpose)
    if not hmac.compare_digest(str(claims.get("nonce", "")), state["n"]):
        return _back_to_app(request, error="failed", purpose=purpose)
    enc = None
    if purpose == "delete":
        if not apple_code:
            return _back_to_app(request, error="failed", purpose=purpose)
        cipher: Cipher = request.app.state.cipher
        enc = cipher.enc(apple_code)
    code = _new_handoff(db, purpose, "apple", sub, state["c"], enc)
    return _back_to_app(request, code=code, purpose=purpose)


class ExchangeIn(BaseModel):
    code: str = Field(..., min_length=1, max_length=200)
    code_verifier: str = Field(..., pattern=r"^[A-Za-z0-9._~-]{43,128}$")


@router.post("/exchange", dependencies=[per_ip("auth", 30, 60)])
def exchange(body: ExchangeIn, request: Request, db: Session = Depends(get_db)):
    """The code from the deep link (purpose signin) and the app's code_verifier → the same tokens as
    POST /v1/auth/apple. A code works once, for 2 minutes."""
    row = take_handoff(db, body.code, body.code_verifier, "signin")
    if row is None:
        raise ApiError(400, "handoff_invalid", "로그인을 마치지 못했어요. 다시 시도해 주세요.")
    return _session_for(db, row.provider, row.sub, request.app.state.settings.jwt_secret)
