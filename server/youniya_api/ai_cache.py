"""Explicit Gemini context caches for a feature's fixed prompt (rules and examples).

Implicit caching is automatic, but on gemini-3.8-flash only from 4,096 input tokens. An explicit
cache needs 1,024 (checked 20261107: the prism's fixed part is 2,774 tokens; the telescope and
monthly ones are 319–441, too small, and are left alone after one try). A cache is made once a
feature has had CACHE_FROM_PER_HOUR requests in the last hour, kept for an hour, extended while the
requests keep coming and left to expire when they stop. A new prompt or model makes a new one.
Requests are counted in rate_hits, so every server instance counts together."""

import hashlib
import logging
import time
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import delete, func, select

from .llm import BASE
from .models import AiCache, RateHit

log = logging.getLogger(__name__)
CACHE_FROM_PER_HOUR = 10
TTL = timedelta(hours=1)
EXTEND_WHEN_LEFT = timedelta(minutes=30)
TOO_SMALL_RETRY = timedelta(days=1)


def cache_key(model: str, prefix: str) -> str:
    return f"{model}:{hashlib.sha256(prefix.encode()).hexdigest()[:16]}"


class CacheManager:
    def __init__(self, sessions, api_key: str | None):
        self.sessions, self.api_key = sessions, api_key

    def for_request(self, feature: str, model: str, prefix: str) -> str | None:
        """Counts this request and returns a cache name to use, or None to send the prompt in full.
        Never raises: a cache problem only means a full-price request."""
        if not self.api_key or not prefix:
            return None
        try:
            return self._for_request(feature, model, prefix)
        except Exception as e:  # noqa: BLE001
            log.warning("context cache for %s skipped: %s", feature, type(e).__name__)
            return None

    def _for_request(self, feature: str, model: str, prefix: str) -> str | None:
        now = datetime.now(timezone.utc)
        key = cache_key(model, prefix)
        with self.sessions() as db:
            db.add(RateHit(key=f"ai:{feature}", at=time.time()))
            db.commit()
            recent = db.scalar(select(func.count()).select_from(RateHit).where(
                RateHit.key == f"ai:{feature}", RateHit.at > time.time() - 3600))
            row = db.get(AiCache, feature)
            live = row is not None and row.key == key and row.expires_at.replace(tzinfo=timezone.utc) > now
            if live and row.name is None:
                return None  # too small for this model: tried, and waiting before trying again
            if recent < CACHE_FROM_PER_HOUR:
                return row.name if live else None
            if live:
                if row.expires_at.replace(tzinfo=timezone.utc) - now < EXTEND_WHEN_LEFT:
                    self._extend(row.name)
                    row.expires_at = now + TTL
                    db.commit()
                return row.name
            name = self.create(model, prefix)
            row = row or AiCache(feature=feature)
            row.key, row.name = key, name
            row.expires_at = now + (TTL if name else TOO_SMALL_RETRY)
            db.add(row)
            db.commit()
            return name

    def create(self, model: str, prefix: str, ttl: timedelta = TTL) -> str | None:
        """The cache's name, or None when the prefix is too small to cache."""
        r = httpx.post(f"{BASE}/cachedContents", headers={"x-goog-api-key": self.api_key}, timeout=30, json={
            "model": f"models/{model}", "contents": [{"role": "user", "parts": [{"text": prefix}]}],
            "ttl": f"{int(ttl.total_seconds())}s"})
        if r.status_code == 400 and "too small" in r.text:
            return None
        r.raise_for_status()
        return r.json()["name"]

    def _extend(self, name: str) -> None:
        httpx.patch(f"{BASE}/{name}", headers={"x-goog-api-key": self.api_key}, timeout=30,
                    json={"ttl": f"{int(TTL.total_seconds())}s"}).raise_for_status()

    def drop(self, feature: str) -> None:
        """Deletes a feature's cache now (the monthly batch, when it is done)."""
        with self.sessions() as db:
            row = db.get(AiCache, feature)
            if row and row.name:
                httpx.delete(f"{BASE}/{row.name}", headers={"x-goog-api-key": self.api_key}, timeout=30)
            db.execute(delete(AiCache).where(AiCache.feature == feature))
            db.commit()

    def batch(self, feature: str, model: str, prefix: str, hours: float = 2) -> str | None:
        """A cache for a batch job, made up front (no request count needed)."""
        name = self.create(model, prefix, timedelta(hours=hours))
        with self.sessions() as db:
            row = db.get(AiCache, feature) or AiCache(feature=feature)
            row.key, row.name = cache_key(model, prefix), name
            row.expires_at = datetime.now(timezone.utc) + timedelta(hours=hours if name else 24)
            db.add(row)
            db.commit()
        return name
