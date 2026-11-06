"""02 로그인 (Apple / Google) and session tokens."""

from datetime import datetime, timezone
from typing import Literal

import jwt
from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from ..deps import ApiError, get_db
from ..models import RefreshToken, User
from ..security import REFRESH_TTL, hash_token, issue_access_token, new_refresh_token
from ..views import aware

router = APIRouter(prefix="/v1/auth", tags=["auth"])


class SignIn(BaseModel):
    id_token: str


class Refresh(BaseModel):
    refresh_token: str


def _tokens(db: Session, user: User, secret: str) -> dict:
    token, token_hash = new_refresh_token()
    db.add(RefreshToken(token_hash=token_hash, user_id=user.id,
                        expires_at=datetime.now(timezone.utc) + REFRESH_TTL))
    db.commit()
    return {
        "access_token": issue_access_token(user.id, secret),
        "refresh_token": token,
        "user_id": user.id,
        "needs_consent": user.consented_at is None,
    }


@router.post("/refresh")
def refresh(body: Refresh, request: Request, db: Session = Depends(get_db)):
    """Rotates the refresh token: the old one stops working."""
    row = db.get(RefreshToken, hash_token(body.refresh_token))
    if row is None or aware(row.expires_at) < datetime.now(timezone.utc):
        raise ApiError(401, "token_expired", "로그인이 만료됐어요. 다시 로그인해 주세요.")
    user = db.get(User, row.user_id)
    db.delete(row)
    return _tokens(db, user, request.app.state.settings.jwt_secret)


@router.post("/logout", status_code=204)
def logout(body: Refresh, db: Session = Depends(get_db)):
    db.execute(delete(RefreshToken).where(RefreshToken.token_hash == hash_token(body.refresh_token)))
    db.commit()


# Registered last so /refresh and /logout are matched first.
@router.post("/{provider}")
def sign_in(provider: Literal["apple", "google"], body: SignIn, request: Request, db: Session = Depends(get_db)):
    try:
        sub = request.app.state.verifier.verify(provider, body.id_token)
    except (jwt.InvalidTokenError, jwt.PyJWKClientError):
        raise ApiError(401, "invalid_id_token", "로그인 정보를 확인하지 못했어요.")
    user = db.scalar(select(User).where(User.provider == provider, User.provider_sub == sub))
    if user is None:
        user = User(provider=provider, provider_sub=sub, settings={})
        db.add(user)
        db.flush()
    return _tokens(db, user, request.app.state.settings.jwt_secret)
