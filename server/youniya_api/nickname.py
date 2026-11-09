"""별지기 이름 (기획서 15장): one per account, unique ignoring case, changed at most once in 30 days."""

import re
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import User
from .privacy import is_hurtful

CHANGE_EVERY = timedelta(days=30)
_FORM = re.compile(r"^[가-힣A-Za-z0-9]{2,12}$")
# 사칭: names that look like the service or its staff.
_RESERVED = ("운영자", "운영진", "관리자", "공식", "고객센터", "youniya", "유니야", "admin", "official", "staff",
             "system", "별지기운영")
_EXTRA_HURTFUL = ("ㅅㅂ", "ㅂㅅ", "좆", "섹스", "fuck", "shit", "bitch")


def key(name: str) -> str:
    return name.strip().lower()


def problem(db: Session, name: str, user: User | None = None) -> str | None:
    """None when `name` can be taken by `user`, else the reason: form | hurtful | reserved | taken."""
    name = name.strip()
    if not _FORM.match(name):
        return "form"
    low = name.lower()
    if is_hurtful(low) or any(w in low for w in _EXTRA_HURTFUL):
        return "hurtful"
    if any(w in low for w in _RESERVED):
        return "reserved"
    owner = db.scalar(select(User.id).where(User.nickname_key == low))
    if owner is not None and (user is None or owner != user.id):
        return "taken"
    return None


MESSAGES = {
    "form": "한글, 영문, 숫자로 2~12자까지 지을 수 있어요.",
    "hurtful": "다른 이에게 상처가 될 수 있는 이름이에요.",
    "reserved": "운영자나 서비스로 보일 수 있는 이름이에요.",
    "taken": "이미 다른 별지기가 쓰고 있는 이름이에요.",
}


def next_change(user: User) -> datetime | None:
    """When the name can change again; None when it can change now. The first name is chosen any time;
    each name then stays 30 days."""
    if user.nickname is None or user.nickname_changed_at is None or user.nickname_rename_requested_at is not None:
        return None  # an operator's rename request (18.3) lifts the wait
    at = user.nickname_changed_at
    at = at if at.tzinfo else at.replace(tzinfo=timezone.utc)
    return at + CHANGE_EVERY if at + CHANGE_EVERY > datetime.now(timezone.utc) else None
