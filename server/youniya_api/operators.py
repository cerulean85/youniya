"""운영자 계정 (기획서 18장): invitations, password + TOTP sign-in, sessions, roles and the audit log."""

import base64
import hashlib
import hmac
import secrets
import struct
import time
from datetime import datetime, timedelta, timezone
from urllib.parse import quote

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import AdminAudit, Operator, OperatorChallenge, OperatorSession
from .views import aware

ROLES = ("owner", "moderator")
MAX_FAILURES = 5
LOCK_FOR = timedelta(minutes=15)
CHALLENGE_FOR = timedelta(minutes=5)
SESSION_FOR = timedelta(hours=12)
INVITE_FOR = timedelta(days=3)
ISSUER = "YOUNIYA Admin"

_hasher = PasswordHasher()
_DUMMY = _hasher.hash(secrets.token_urlsafe(16))


def _sha(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def now() -> datetime:
    return datetime.now(timezone.utc)


# --- TOTP (RFC 6238: SHA-1, 30 s, 6 digits) -------------------------------------------------------

def new_totp_secret() -> str:
    return base64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")


def totp_at(secret: str, step: int) -> str:
    key = base64.b32decode(secret + "=" * (-len(secret) % 8))
    digest = hmac.new(key, struct.pack(">Q", step), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    code = (struct.unpack(">I", digest[offset:offset + 4])[0] & 0x7FFFFFFF) % 1_000_000
    return f"{code:06d}"


def totp_step(at: float | None = None) -> int:
    return int((at if at is not None else time.time()) // 30)


def check_totp(secret: str, code: str, last_step: int | None, at: float | None = None) -> int | None:
    """The step the code belongs to (one step either side for clock drift), or None. A step at or
    before `last_step` was used already."""
    code = code.strip().replace(" ", "")
    here = totp_step(at)
    for step in (here, here - 1, here + 1):
        if hmac.compare_digest(totp_at(secret, step), code) and (last_step is None or step > last_step):
            return step
    return None


def otpauth_uri(email: str, secret: str) -> str:
    return f"otpauth://totp/{quote(ISSUER)}:{quote(email)}?secret={secret}&issuer={quote(ISSUER)}"


# --- accounts --------------------------------------------------------------------------------------

def invite(db: Session, email: str, role: str, invited_by: str | None) -> tuple[Operator, str]:
    """A new operator (or a fresh invitation for one not yet set up). Returns the one-time setup token."""
    email = email.strip().lower()
    row = db.scalar(select(Operator).where(Operator.email == email))
    if row is not None and row.status != "invited":
        raise ValueError("exists")
    token = secrets.token_urlsafe(32)
    row = row or Operator(email=email, role=role, status="invited", invited_by=invited_by)
    row.role, row.invite_hash, row.invite_expires_at = role, _sha(token), now() + INVITE_FOR
    db.add(row)
    db.flush()
    return row, token


def by_invite(db: Session, token: str) -> Operator | None:
    row = db.scalar(select(Operator).where(Operator.invite_hash == _sha(token)))
    if row is None or row.status != "invited" or aware(row.invite_expires_at) < now():
        return None
    return row


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def password_ok(row: Operator | None, password: str) -> bool:
    try:
        _hasher.verify(row.password_hash if row and row.password_hash else _DUMMY, password)
    except (VerificationError, InvalidHashError):
        return False
    return row is not None and row.password_hash is not None


def locked(row: Operator) -> datetime | None:
    return aware(row.locked_until) if row.locked_until and aware(row.locked_until) > now() else None


def failed(db: Session, row: Operator) -> datetime | None:
    """One more failure; the lock's end when this one locks the account."""
    row.failed_count = (row.failed_count or 0) + 1
    if row.failed_count >= MAX_FAILURES:
        row.failed_count, row.locked_until = 0, now() + LOCK_FOR
    db.commit()
    return locked(row)


def challenge(db: Session, row: Operator) -> str:
    token = secrets.token_urlsafe(32)
    db.add(OperatorChallenge(token_hash=_sha(token), operator_id=row.id, expires_at=now() + CHALLENGE_FOR))
    db.commit()
    return token


def take_challenge(db: Session, token: str) -> Operator | None:
    ch = db.get(OperatorChallenge, _sha(token))
    if ch is None:
        return None
    db.delete(ch)
    db.flush()
    if aware(ch.expires_at) < now():
        return None
    return db.get(Operator, ch.operator_id)


def start_session(db: Session, row: Operator) -> tuple[str, datetime]:
    token = secrets.token_urlsafe(32)
    expires = now() + SESSION_FOR
    db.add(OperatorSession(token_hash=_sha(token), operator_id=row.id, expires_at=expires))
    row.failed_count, row.locked_until, row.last_seen_at = 0, None, now()
    db.commit()
    return token, expires


def session_operator(db: Session, token: str) -> Operator | None:
    s = db.get(OperatorSession, _sha(token))
    if s is None or aware(s.expires_at) < now():
        return None
    row = db.get(Operator, s.operator_id)
    if row is None or row.status != "active":
        return None
    if row.last_seen_at is None or aware(row.last_seen_at) < now() - timedelta(minutes=5):
        row.last_seen_at = now()
        db.commit()
    return row


def end_session(db: Session, token: str) -> None:
    if (s := db.get(OperatorSession, _sha(token))) is not None:
        db.delete(s)
        db.commit()


def end_all_sessions(db: Session, operator_id: str) -> None:
    for s in db.scalars(select(OperatorSession).where(OperatorSession.operator_id == operator_id)):
        db.delete(s)


def audit(db: Session, operator: Operator | None, action: str, target: str | None = None,
          reason: str | None = None, **detail) -> AdminAudit:
    row = AdminAudit(operator_id=operator.id if operator else None, operator_email=operator.email if operator else None,
                     action=action, target=target, reason=reason, detail=detail or None)
    db.add(row)
    return row


def view(row: Operator) -> dict:
    from .views import iso
    return {"id": row.id, "email": row.email, "role": row.role, "status": row.status,
            "totp": row.totp_secret_enc is not None, "last_seen_at": iso(row.last_seen_at),
            "created_at": iso(row.created_at)}
