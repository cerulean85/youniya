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
    return int(user.free_telescope_month != this_month()) + int(not user.free_telescope_used)


def stories_left(user: User) -> int:
    return int(not user.free_story_used)


def summary(user: User, per_day: int) -> dict:
    return {"free_star_today": stars_left(user, per_day), "free_telescope": telescopes_left(user),
            "free_story": stories_left(user)}


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


def use_telescope(db: Session, user: User) -> bool:
    """This month's free one first (it does not carry over), then the sign-up one."""
    month = this_month()
    return _claim(db, user, or_(User.free_telescope_month.is_(None), User.free_telescope_month != month),
                  free_telescope_month=month) or \
        _claim(db, user, User.free_telescope_used.is_(False), free_telescope_used=True)


def use_story(db: Session, user: User) -> bool:
    return _claim(db, user, User.free_story_used.is_(False), free_story_used=True)
