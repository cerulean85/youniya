"""Sliding-window request limits, mainly in front of the model calls.

Counted in the database, so the limits hold across every server instance
(Vercel starts many short-lived ones; memory counters would barely limit anything)."""

import random
import time

from fastapi import Depends, Request
from sqlalchemy import delete, func, insert, select, text
from sqlalchemy.orm import Session, sessionmaker

from .deps import ApiError, current_user
from .models import RateHit, User


LONGEST_WINDOW = 86400


class RateLimiter:
    def __init__(self, sessions: sessionmaker[Session]):
        self._sessions = sessions

    def hit(self, key: str, limit: int, seconds: int, now: float | None = None) -> int | None:
        """Counts a request. Returns seconds to wait when over the limit, else None."""
        now = time.time() if now is None else now
        with self._sessions() as db, db.begin():
            if db.get_bind().dialect.name == "postgresql":
                # Serialize requests for the same key, so two at once cannot both slip under the limit.
                db.execute(text("select pg_advisory_xact_lock(hashtext(:k))"), {"k": key})
            db.execute(delete(RateHit).where(RateHit.key == key, RateHit.at <= now - seconds))
            if random.random() < 0.01:
                # Keys that are never hit again: drop anything older than the longest window.
                db.execute(delete(RateHit).where(RateHit.at <= now - LONGEST_WINDOW))
            count, oldest = db.execute(select(func.count(), func.min(RateHit.at)).where(RateHit.key == key)).one()
            if count >= limit:
                return int(oldest + seconds - now) + 1
            db.execute(insert(RateHit).values(key=key, at=now))
            return None


def _check(request: Request, key: str, limit: int, seconds: int) -> None:
    wait = request.app.state.limiter.hit(key, limit, seconds)
    if wait:
        raise ApiError(429, "rate_limited", "잠시 뒤에 다시 시도해 주세요.", retry_after=wait)


def per_user(name: str, limit: int, seconds: int):
    def dep(request: Request, user: User = Depends(current_user)) -> None:
        _check(request, f"{name}:{user.id}", limit, seconds)
    return Depends(dep)


def per_ip(name: str, limit: int, seconds: int):
    def dep(request: Request) -> None:
        _check(request, f"{name}:{client_ip(request)}", limit, seconds)
    return Depends(dep)


def client_ip(request: Request) -> str:
    """Behind Vercel the socket peer is the proxy; the caller is the first X-Forwarded-For entry.
    Trusted only behind a proxy that sets it (TRUST_PROXY), or anyone could pick their own key."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded and request.app.state.settings.trust_proxy:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "-"
