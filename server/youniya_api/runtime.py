"""Settings an owner changes from the console (A-11 초대 로그인, A-12 점검·최소 버전), over the environment.
Read on every request through a 20-second cache, so a change reaches every instance within that."""

import time
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import RuntimeSetting

TTL = 20.0


def _load(sessions) -> dict:
    with sessions() as db:
        return {r.key: r.value.get("v") for r in db.scalars(select(RuntimeSetting))}


def overrides(app) -> dict:
    hit = getattr(app.state, "runtime_cache", None)
    if hit and time.monotonic() - hit[0] < TTL:
        return hit[1]
    try:
        values = _load(app.state.sessions)
    except Exception:  # noqa: BLE001 — a database hiccup must not close the app; the environment holds
        values = hit[1] if hit else {}
    app.state.runtime_cache = (time.monotonic(), values)
    return values


def forget(app) -> None:
    app.state.runtime_cache = None


def _time(v) -> datetime | None:
    return datetime.fromisoformat(v) if v else None


def maintenance(app) -> tuple[datetime | None, datetime | None]:
    o, s = overrides(app), app.state.settings
    if "maintenance" in o:
        m = o["maintenance"] or {}
        return _time(m.get("start")), _time(m.get("end"))
    return s.maintenance_start, s.maintenance_end


def in_maintenance(app, at: datetime | None = None) -> bool:
    start, end = maintenance(app)
    at = at or datetime.now(timezone.utc)
    return bool(start and end and start <= at < end)


def min_app_version(app) -> str:
    return overrides(app).get("min_app_version") or app.state.settings.min_app_version


def invite_login(app) -> bool:
    o = overrides(app)
    return bool(o["invite_login"]) if "invite_login" in o else app.state.settings.invite_login


def put(db: Session, key: str, value, by: str | None) -> None:
    row = db.get(RuntimeSetting, key) or RuntimeSetting(key=key)
    row.value, row.updated_by = {"v": value}, by
    db.add(row)
