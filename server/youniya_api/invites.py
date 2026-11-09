"""초대 계정 (App Review). Passwords are kept only as argon2id hashes."""

import secrets

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from sqlalchemy.orm import Session

from .models import InviteAccount, User

_hasher = PasswordHasher()
# Checked when the login does not exist, so a wrong login takes as long as a wrong password.
_DUMMY = _hasher.hash(secrets.token_urlsafe(16))

# Passwords a reviewer types by hand on a phone: two words and four digits, e.g. "moon-river-4827".
# No look-alike letters, no symbols but "-". Sign-in is rate limited, so this is plenty.
_WORDS = ("moon", "star", "river", "cloud", "ocean", "comet", "light", "night", "dream", "maple",
          "snow", "wave", "bloom", "dawn", "sky", "orbit", "glow", "tide", "breeze", "forest",
          "harbor", "meadow", "pebble", "lantern", "violet", "silver", "amber", "coral", "willow", "spark")


def new_password() -> str:
    a, b = secrets.SystemRandom().sample(_WORDS, 2)
    return f"{a}-{b}-{secrets.randbelow(10_000):04d}"


def check(db: Session, login: str, password: str) -> User | None:
    row = db.get(InviteAccount, login.strip().lower())
    try:
        _hasher.verify(row.password_hash if row else _DUMMY, password)
    except (VerificationError, InvalidHashError):
        return None
    if row is None or row.disabled:  # A-11 꺼 둔 계정
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
    password = password or new_password()
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
    password = new_password()
    row.password_hash = _hasher.hash(password)
    db.commit()
    return password
