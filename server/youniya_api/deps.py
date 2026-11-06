from collections.abc import Iterator

import jwt
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .models import User
from .security import Cipher, read_access_token


class ApiError(Exception):
    """Rendered as `{"error": {"code", "message", ...}}`."""

    def __init__(self, status: int, code: str, message: str, **extra):
        self.status, self.code, self.message, self.extra = status, code, message, extra


def get_db(request: Request) -> Iterator[Session]:
    with request.app.state.sessions() as db:
        yield db


def get_cipher(request: Request) -> Cipher:
    return request.app.state.cipher


_bearer = HTTPBearer(auto_error=False)


def current_user(
    request: Request,
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    # 39 다시 로그인해 주세요
    if creds is None:
        raise ApiError(401, "unauthorized", "로그인이 필요해요.")
    try:
        user_id = read_access_token(creds.credentials, request.app.state.settings.jwt_secret)
    except jwt.ExpiredSignatureError:
        raise ApiError(401, "token_expired", "로그인이 만료됐어요. 다시 로그인해 주세요.")
    except jwt.InvalidTokenError:
        raise ApiError(401, "unauthorized", "로그인이 필요해요.")
    user = db.get(User, user_id)
    if user is None:
        raise ApiError(401, "unauthorized", "로그인이 필요해요.")
    return user


def consented_user(user: User = Depends(current_user)) -> User:
    """Writing is sensitive information: nothing is stored before 11 가입 동의."""
    if user.consented_at is None:
        raise ApiError(403, "consent_required", "시작하기 전에 동의가 필요해요.")
    return user
