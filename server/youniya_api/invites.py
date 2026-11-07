"""초대 계정 (App Review). Passwords are kept only as argon2id hashes."""

import secrets

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from sqlalchemy.orm import Session

from .models import InviteAccount, User

_hasher = PasswordHasher()
# Checked when the login does not exist, so a wrong login takes as long as a wrong password.
_DUMMY = _hasher.hash(secrets.token_urlsafe(16))


def check(db: Session, login: str, password: str) -> User | None:
    row = db.get(InviteAccount, login.strip().lower())
    try:
        _hasher.verify(row.password_hash if row else _DUMMY, password)
    except (VerificationError, InvalidHashError):
        return None
    if row is None:
        return None
    if _hasher.check_needs_rehash(row.password_hash):
        row.password_hash = _hasher.hash(password)
        db.commit()
    return db.get(User, row.user_id)


def create(db: Session, login: str, password: str | None = None) -> tuple[User, str]:
    """A new account with a fresh password (returned once, never stored in the clear)."""
    login = login.strip().lower()
    if db.get(InviteAccount, login):
        raise ValueError(f"{login} already exists")
    password = password or secrets.token_urlsafe(12)
    user = User(provider="invite", provider_sub=login, settings={})
    db.add(user)
    db.flush()
    db.add(InviteAccount(login=login, password_hash=_hasher.hash(password), user_id=user.id))
    db.commit()
    return user, password


def reset(db: Session, login: str) -> str:
    row = db.get(InviteAccount, login.strip().lower())
    if row is None:
        raise ValueError(f"{login} does not exist")
    password = secrets.token_urlsafe(12)
    row.password_hash = _hasher.hash(password)
    db.commit()
    return password
