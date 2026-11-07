"""Stars: 05 별 만들기, 07 별 카드, 12 별 상세, 14–16 다시 쓰기, 15 삭제, 34 임시 저장,
115–119 기록, 82 밝기 흐름, 08/86/66 성장."""

from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..deps import ApiError, consented_user, get_cipher, get_db
from ..models import Draft, Nebula, Star, User
from ..prism.filters import CRISIS_GUIDANCE, has_crisis_signal
from ..rules import DEEP_DEPTH_SCORE, FIRST_STAGE_STARS, STAGE_NAMES, SUPERNOVA_STARLIGHT, growth_stage
from ..security import Cipher
from ..views import aware, iso, local, shared_star_ids, star_view
from ..ratelimit import per_user

router = APIRouter(prefix="/v1", tags=["stars"])

Mood = Literal["calm", "sorrow", "anger", "insight"]


class StarIn(BaseModel):
    mood: Mood
    title: str = Field("", max_length=60)
    body: str = Field(..., min_length=1, max_length=20000)
    mode: Literal["float", "keep"]  # 별 띄우기 | 조용히 간직하기
    rewrite_of: str | None = None  # 14 다시 쓰기


class DraftIn(BaseModel):
    mood: Mood = "calm"
    title: str = Field("", max_length=60)
    body: str = Field("", max_length=20000)


def owned_star(db: Session, user: User, star_id: str) -> Star:
    star = db.get(Star, star_id)
    if star is None or star.user_id != user.id:
        raise ApiError(404, "not_found", "별을 찾지 못했어요.")
    return star


def _apply(star: Star, analysis: dict, cipher: Cipher) -> None:
    star.state = "floated"
    star.starlight = analysis["starlight"]
    star.depth_score = analysis["scores"]["depth"]
    star.analysis_enc = cipher.enc_json(analysis)
    star.analysis_failed = False


def _float(star: Star, request: Request, cipher: Cipher) -> str:
    """Runs the prism on a star. Returns the prism status; raises on unscoreable text."""
    result = request.app.state.prism.evaluate(cipher.dec(star.title_enc), cipher.dec(star.body_enc))
    if result.status in ("too_short", "foul"):
        raise ApiError(422, result.status, result.message)
    if result.status == "ok":
        _apply(star, result.analysis, cipher)
    elif result.status == "failed":
        star.analysis_failed = True
    return result.status


def _response(db: Session, star: Star, cipher: Cipher, crisis: bool) -> dict:
    out = {"star": star_view(star, cipher, shared=star.id in shared_star_ids(db, star.user_id)),
           "crisis": CRISIS_GUIDANCE if crisis else None}
    if star.rewrite_of:
        prev = db.get(Star, star.rewrite_of)
        # 16 같은 마음, 다른 빛
        out["compare"] = {"previous_starlight": prev.starlight if prev else None, "starlight": star.starlight}
    return out


@router.post("/stars", status_code=201, dependencies=[per_user("prism", 30, 3600)])
def create_star(body: StarIn, request: Request, user: User = Depends(consented_user),
                db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    if body.rewrite_of:
        owned_star(db, user, body.rewrite_of)
    title = body.title.strip() or "제목 없는 별"
    star = Star(user_id=user.id, mood=body.mood, title_enc=cipher.enc(title), body_enc=cipher.enc(body.body),
                state="kept", rewrite_of=body.rewrite_of)
    # 37 위기 돌봄: the writing is always saved as written, but never scored.
    crisis = has_crisis_signal(f"{title}\n{body.body}")
    star.crisis = crisis
    if body.mode == "float" and not crisis:
        _float(star, request, cipher)  # 422 before anything is stored when it can't be floated
    db.add(star)
    draft = db.get(Draft, user.id)
    if draft:
        db.delete(draft)
    db.commit()
    return _response(db, star, cipher, crisis)


@router.post("/stars/{star_id}/float", dependencies=[per_user("prism", 30, 3600)])
def float_star(star_id: str, request: Request, user: User = Depends(consented_user),
               db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """36 다시 시도, or floating a kept star later."""
    star = owned_star(db, user, star_id)
    if star.state == "floated":
        raise ApiError(409, "already_floated", "이미 떠 있는 별이에요.")
    if star.crisis:
        return _response(db, star, cipher, crisis=True)
    status = _float(star, request, cipher)
    db.commit()
    if status == "failed":
        raise ApiError(502, "analysis_failed", "별을 읽지 못했어요. 글은 그대로 보관돼요.")
    return _response(db, star, cipher, crisis=False)


@router.get("/stars")
def list_stars(
    user: User = Depends(consented_user),
    db: Session = Depends(get_db),
    cipher: Cipher = Depends(get_cipher),
    state: Literal["floated", "kept"] | None = None,
    mood: Mood | None = None,
    q: str | None = Query(None, max_length=50, description="117 제목 · 본문 검색"),
    month: str | None = Query(None, pattern=r"^\d{4}-\d{2}$", description="YYYY-MM, Korean time"),
    before: datetime | None = None,
    limit: int = Query(50, ge=1, le=200),
):
    stmt = select(Star).where(Star.user_id == user.id).order_by(Star.created_at.desc())
    if state:
        stmt = stmt.where(Star.state == state)
    if mood:
        stmt = stmt.where(Star.mood == mood)
    if before:
        stmt = stmt.where(Star.created_at < before)
    shared = shared_star_ids(db, user.id)
    items = []
    # Titles and bodies are encrypted, so search and month filtering happen here.
    for star in db.scalars(stmt):
        if month and local(star.created_at).strftime("%Y-%m") != month:
            continue
        if q and q not in cipher.dec(star.title_enc) and q not in cipher.dec(star.body_enc):
            continue
        items.append(star_view(star, cipher, shared=star.id in shared, body=False))
        if len(items) == limit:
            break
    return {"items": items, "next_before": items[-1]["created_at"] if len(items) == limit else None}


@router.get("/stars/summary")
def summary(user: User = Depends(consented_user), db: Session = Depends(get_db),
            month: str | None = Query(None, pattern=r"^\d{4}-\d{2}$", description="116 달력 month")):
    stars = db.scalars(select(Star).where(Star.user_id == user.id)).all()
    by_month: dict[str, int] = {}
    days: dict[int, int] = {}
    for s in stars:
        t = local(s.created_at)
        by_month[t.strftime("%Y-%m")] = by_month.get(t.strftime("%Y-%m"), 0) + 1
        if month and t.strftime("%Y-%m") == month:
            days[t.day] = days.get(t.day, 0) + 1
    floated = [s for s in stars if s.state == "floated"]
    return {
        "total": len(stars),
        "floated": len(floated),
        "kept": len(stars) - len(floated),
        "deep": sum(1 for s in floated if (s.depth_score or 0) >= DEEP_DEPTH_SCORE),
        "supernova": sum(1 for s in floated if (s.starlight or 0) >= SUPERNOVA_STARLIGHT),
        "by_month": [{"month": m, "count": c} for m, c in sorted(by_month.items(), reverse=True)],
        "calendar": {"month": month, "days": [{"day": d, "count": c} for d, c in sorted(days.items())]}
        if month else None,
    }


@router.get("/stars/{star_id}")
def get_star(star_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db),
             cipher: Cipher = Depends(get_cipher)):
    star = owned_star(db, user, star_id)
    return star_view(star, cipher, shared=star.id in shared_star_ids(db, user.id))


@router.delete("/stars/{star_id}", status_code=204)
def delete_star(star_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """15 영구 삭제: the writing, its analysis and its plaza share go."""
    star = owned_star(db, user, star_id)
    for n in db.scalars(select(Nebula).where(Nebula.user_id == user.id)):
        if star.id in n.star_ids:
            n.star_ids = [i for i in n.star_ids if i != star.id]
    db.delete(star)
    db.commit()


@router.get("/starlight/trend")
def trend(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """82 나의 별빛 흐름: the last 8 stars and monthly averages. Only against my own past."""
    floated = db.scalars(select(Star).where(Star.user_id == user.id, Star.state == "floated")
                         .order_by(Star.created_at.desc())).all()
    recent = list(reversed(floated[:8]))
    months: dict[str, list[int]] = {}
    for s in floated:
        months.setdefault(local(s.created_at).strftime("%Y-%m"), []).append(s.starlight)
    this_month = local(datetime.now().astimezone()).strftime("%Y-%m")
    return {
        "recent": [{"star_id": s.id, "created_at": iso(s.created_at), "starlight": s.starlight} for s in recent],
        "average": round(sum(s.starlight for s in recent) / len(recent)) if recent else None,
        "monthly": [{"month": m, "average": round(sum(v) / len(v)), "in_progress": m == this_month}
                    for m, v in sorted(months.items())[-3:]],
        "enough": len(recent) >= 3,  # 109 흐름을 그리기엔 별이 조금 적어요
    }


@router.get("/growth")
def growth(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """08 나의 성운, 86 네 걸음, 66 지나온 순간.

    `stage` is 0 until there are 12 stars (floated or kept), then 1–4; `stage_name` is null at 0.
    `next.needs` holds [now, goal] pairs for the next stage: `stars` at 0 (별 N/12), `deep` at 1,
    `deep` and `starlight_900` at 2, `deep` and `moods` at 3. `next` is null at 4."""
    stars = db.scalars(select(Star).where(Star.user_id == user.id).order_by(Star.created_at)).all()
    floated = [s for s in stars if s.state == "floated"]
    deep = sum(1 for s in floated if (s.depth_score or 0) >= DEEP_DEPTH_SCORE)
    brightest = max((s.starlight or 0 for s in floated), default=0)
    moods = len({s.mood for s in floated})
    stage = growth_stage(len(stars), deep, brightest, moods)
    nxt = {1: {"stars": [len(stars), FIRST_STAGE_STARS]},
           2: {"deep": [deep, 6]},
           3: {"deep": [deep, 15], "starlight_900": [int(brightest >= SUPERNOVA_STARLIGHT), 1]},
           4: {"deep": [deep, 30], "moods": [moods, 3]}}.get(stage + 1)

    first_nebula = db.scalar(select(Nebula.created_at).where(Nebula.user_id == user.id)
                             .order_by(Nebula.created_at).limit(1))
    kept = [s for s in stars if s.state == "kept"]
    milestones = [
        ("first_star", "첫 별을 띄웠어요", floated[0].created_at if floated else None),
        ("first_kept", "처음 조용히 간직했어요", kept[0].created_at if kept else None),
        ("ten_stars", "별 10개가 모였어요", floated[9].created_at if len(floated) >= 10 else None),
        ("first_nebula", "첫 성운을 그렸어요", first_nebula),
    ]
    return {
        "stage": stage,
        "stage_name": STAGE_NAMES[stage - 1] if stage else None,
        "floated": len(floated),
        "deep": deep,
        "supernova": sum(1 for s in floated if (s.starlight or 0) >= SUPERNOVA_STARLIGHT),
        "next": {"stage": stage + 1, "stage_name": STAGE_NAMES[stage], "needs": nxt} if nxt else None,
        "milestones": sorted(
            [{"key": k, "title": t, "at": iso(at)} for k, t, at in milestones if at],
            key=lambda m: m["at"],
        ),
    }


@router.get("/drafts/current")
def get_draft(user: User = Depends(consented_user), db: Session = Depends(get_db),
              cipher: Cipher = Depends(get_cipher)):
    d = db.get(Draft, user.id)
    if d is None:
        return None
    return {"mood": d.mood, "title": cipher.dec(d.title_enc), "body": cipher.dec(d.body_enc),
            "updated_at": iso(d.updated_at)}


@router.put("/drafts/current")
def save_draft(body: DraftIn, user: User = Depends(consented_user), db: Session = Depends(get_db),
               cipher: Cipher = Depends(get_cipher)):
    """34 임시 저장하고 나가기"""
    d = db.get(Draft, user.id) or Draft(user_id=user.id)
    d.mood, d.title_enc, d.body_enc = body.mood, cipher.enc(body.title), cipher.enc(body.body)
    db.add(d)
    db.commit()
    return {"saved": True, "updated_at": iso(aware(d.updated_at)) if d.updated_at else None}


@router.delete("/drafts/current", status_code=204)
def discard_draft(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    d = db.get(Draft, user.id)
    if d:
        db.delete(d)
        db.commit()
