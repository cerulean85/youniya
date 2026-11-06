"""Sliding-window request limits, mainly in front of the model calls.

Kept in memory, so the limits hold per server process. Behind several processes,
move the counters to a shared store (e.g. Redis)."""

import time
from collections import defaultdict, deque
from threading import Lock

from fastapi import Depends, Request

from .deps import ApiError, current_user
from .models import User


class RateLimiter:
    def __init__(self):
        self._hits: dict[str, deque] = defaultdict(deque)
        self._lock = Lock()

    def hit(self, key: str, limit: int, seconds: int) -> int | None:
        """Counts a request. Returns seconds to wait when over the limit, else None."""
        now = time.monotonic()
        with self._lock:
            hits = self._hits[key]
            while hits and hits[0] <= now - seconds:
                hits.popleft()
            if len(hits) >= limit:
                return int(hits[0] + seconds - now) + 1
            hits.append(now)
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
        _check(request, f"{name}:{request.client.host if request.client else '-'}", limit, seconds)
    return Depends(dep)
