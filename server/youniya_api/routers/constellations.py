"""16장 월별 별자리: each month has its constellation; that month's stars, lit or not, take its
places in the order they were written. Templates: constellation_templates.json (Figma 501:13915),
x and y as fractions of a 342 × 300 canvas, slots in the order they fill."""

import json
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, Path as PathParam
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..deps import ApiError, consented_user, get_cipher, get_db
from ..models import Star, User
from ..prism.engine import split_sentences
from ..rules import DEEP_DEPTH_SCORE
from ..security import Cipher
from ..views import KST, iso, local

router = APIRouter(prefix="/v1/constellations", tags=["constellations"])

TEMPLATES: dict[int, dict] = {int(k): v for k, v in json.loads(
    (Path(__file__).resolve().parents[1] / "constellation_templates.json").read_text()).items()}
MONTH = r"^\d{4}-(0[1-9]|1[0-2])$"


def _months(user: User) -> list[str]:
    """From the month the account was made to this one, newest first."""
    now, start = datetime.now(KST), local(user.created_at)
    y, m, out = now.year, now.month, []
    while (y, m) >= (start.year, start.month):
        out.append(f"{y:04d}-{m:02d}")
        y, m = (y, m - 1) if m > 1 else (y - 1, 12)
    return out


def _stars(db: Session, user: User, month: str) -> list[Star]:
    stars = db.scalars(select(Star).where(Star.user_id == user.id).order_by(Star.created_at)).all()
    return [s for s in stars if local(s.created_at).strftime("%Y-%m") == month]


def _star(s: Star, cipher: Cipher) -> dict:
    return {"id": s.id, "title": cipher.dec(s.title_enc), "mood": s.mood, "moods": s.moods or [s.mood],
            "has_starlight": s.state == "floated", "starlight": s.starlight, "created_at": iso(s.created_at)}


def _summary(month: str, stars: list[Star]) -> dict:
    t = TEMPLATES[int(month[5:])]
    total = len(t["slots"])
    return {"month": month, "key": t["key"], "name": t["name"], "filled": min(len(stars), total), "total": total,
            "complete": len(stars) >= total}


def _check(user: User, month: str) -> None:
    if month not in _months(user):
        raise ApiError(404, "not_found", "아직 열리지 않은 달이에요.")


@router.get("")
def months(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """나의 은하수: every month since joining, newest first, with how full each is."""
    stars = db.scalars(select(Star.created_at).where(Star.user_id == user.id)).all()
    counts: dict[str, int] = {}
    for at in stars:
        counts[local(at).strftime("%Y-%m")] = counts.get(local(at).strftime("%Y-%m"), 0) + 1
    out = []
    for m in _months(user):
        t = TEMPLATES[int(m[5:])]
        n, total = counts.get(m, 0), len(t["slots"])
        out.append({"month": m, "key": t["key"], "name": t["name"], "filled": min(n, total), "total": total,
                    "complete": n >= total})
    return {"items": out}


@router.get("/{month}")
def constellation(month: str = PathParam(..., pattern=MONTH), user: User = Depends(consented_user),
                  db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """{month, key, name, slots:[{index, x, y, star|null}], lines, extra, filled, total, complete, lit, unlit,
    deep}. A month before joining or after this one is 404; a past month with no stars has empty slots.
    `deep`: lit stars with a depth score of 280 or more (70% of 400)."""
    _check(user, month)
    stars = _stars(db, user, month)
    t = TEMPLATES[int(month[5:])]
    slots = [{"index": i, "x": x, "y": y, "star": _star(stars[i], cipher) if i < len(stars) else None}
             for i, (x, y) in enumerate(t["slots"])]
    lit = [s for s in stars if s.state == "floated"]
    return _summary(month, stars) | {
        "slots": slots, "lines": t["lines"], "extra": [_star(s, cipher) for s in stars[len(t["slots"]):]],
        "lit": len(lit), "unlit": len(stars) - len(lit),
        "deep": sum(1 for s in lit if (s.depth_score or 0) >= DEEP_DEPTH_SCORE)}


@router.get("/{month}/story")
def story(month: str = PathParam(..., pattern=MONTH), user: User = Depends(consented_user),
          db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """별자리 이야기: each star's key sentence in time order, never changed. A lit star gives the sentence
    the prism chose; one without starlight, its first sentence."""
    _check(user, month)
    entries = []
    for s in _stars(db, user, month):
        if s.state == "floated" and s.analysis_enc:
            sentence = cipher.dec_json(s.analysis_enc)["impact_quote"]
        else:
            body = cipher.dec(s.body_enc)
            sentence = (split_sentences(body) or [body.strip()])[0]
        entries.append({"star_id": s.id, "date": iso(s.created_at), "title": cipher.dec(s.title_enc),
                        "sentence": sentence, "has_starlight": s.state == "floated"})
    t = TEMPLATES[int(month[5:])]
    return {"month": month, "key": t["key"], "name": t["name"], "entries": entries}
