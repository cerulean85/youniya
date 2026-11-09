"""Shared helpers for turning rows into API responses."""

from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Star, StarShare
from .security import Cipher

KST = ZoneInfo("Asia/Seoul")


def aware(dt: datetime) -> datetime:
    """SQLite hands datetimes back without a zone; they are stored in UTC."""
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def iso(dt: datetime | None) -> str | None:
    return aware(dt).isoformat() if dt else None


def local(dt: datetime) -> datetime:
    """Months, calendar days and 'tonight' follow Korean time."""
    return aware(dt).astimezone(KST)


def shared_star_ids(db: Session, user_id: str) -> set[str]:
    return set(db.scalars(select(StarShare.star_id).where(StarShare.user_id == user_id)))


def star_view(star: Star, cipher: Cipher, shared: bool = False, body: bool = True) -> dict:
    out = {
        "id": star.id,
        "title": cipher.dec(star.title_enc),
        "mood": star.mood,
        "moods": star.moods or [star.mood],
        "state": star.state,  # floated | kept, for builds before 20261109; has_starlight says the same
        "has_starlight": star.state == "floated",
        "locked": star.state == "floated",  # 11.2: body and moods can no longer change
        "created_at": iso(star.created_at),
        "updated_at": iso(star.updated_at),
        "starlight": star.starlight,
        "rewrite_of": star.rewrite_of,
        "analysis_failed": star.analysis_failed,
        "shared": shared,
    }
    if body:
        out["body"] = cipher.dec(star.body_enc)
        out["analysis"] = cipher.dec_json(star.analysis_enc) if star.analysis_enc else None
    return out
