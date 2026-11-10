"""Free uses (기획 확정 20261107). Each is a marker on the user, claimed atomically, so deleting a
star or racing two requests never gives a use back.

- 별 띄우기: free_stars_per_day a day (Korean day), then STAR_FLOAT_COST. Keeping is always free.
- 마음 망원경: one a calendar month (no carry-over) plus one at sign-up.
- 서사 다듬기: one at sign-up."""

from datetime import datetime

from sqlalchemy import or_, update
from sqlalchemy.orm import Session

from .models import User
from .views import KST


def today() -> str:
    return datetime.now(KST).strftime("%Y-%m-%d")


def this_month() -> str:
    return datetime.now(KST).strftime("%Y-%m")


def stars_left(user: User, per_day: int) -> int:
    used = user.free_star_count if user.free_star_day == today() else 0
    return max(0, per_day - used)


def telescopes_left(user: User) -> int:
    """마음 망원경 was removed (20261110): always 0. /v1/me, /v1/coins and 별지기 멤버십 keep their telescope
    fields at 0/false until the apps stop reading them."""
    return 0


def summary(user: User, per_day: int) -> dict:
    return {"free_star_today": stars_left(user, per_day), "free_telescope": telescopes_left(user)}


def _claim(db: Session, user: User, *conditions, **values) -> bool:
    done = db.execute(update(User).where(User.id == user.id, *conditions).values(**values)).rowcount
    db.refresh(user)
    return bool(done)


def use_star(db: Session, user: User, per_day: int) -> bool:
    day = today()
    return (_claim(db, user, or_(User.free_star_day.is_(None), User.free_star_day != day),
                   free_star_day=day, free_star_count=1) if per_day > 0 else False) or \
        _claim(db, user, User.free_star_day == day, User.free_star_count < per_day,
               free_star_count=User.free_star_count + 1)


def use_unlit(db: Session, user: User, per_day: int) -> bool:
    """One of today's 별빛 없이 띄우기 (17.1)."""
    day = today()
    return _claim(db, user, or_(User.unlit_day.is_(None), User.unlit_day != day), unlit_day=day, unlit_count=1) or \
        _claim(db, user, User.unlit_day == day, User.unlit_count < per_day, unlit_count=User.unlit_count + 1)


def unlit_left(user: User, per_day: int) -> int:
    return max(0, per_day - (user.unlit_count if user.unlit_day == today() else 0))


def use_telescope(db: Session, user: User) -> bool:
    """This month's free one first (it does not carry over), then the sign-up one."""
    month = this_month()
    return _claim(db, user, or_(User.free_telescope_month.is_(None), User.free_telescope_month != month),
                  free_telescope_month=month) or \
        _claim(db, user, User.free_telescope_used.is_(False), free_telescope_used=True)
