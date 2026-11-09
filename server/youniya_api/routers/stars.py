"""Stars: 05 별 만들기, 07 별 카드, 12 별 상세, 14–16 다시 쓰기, 15 삭제, 34 임시 저장,
115–119 기록, 82 밝기 흐름, 08/86/66 성장."""

from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from ..deps import ApiError, consented_user, get_cipher, get_db
from ..blocks import hidden_users
from ..models import Draft, Nebula, Star, StarLine, StarLineReport, StarLink, StarShare, TelescopeReport, User, now
from ..prism.filters import CRISIS_GUIDANCE, has_crisis_signal
from .. import ai_cost, allowance, coins, membership, privacy
from .blocks import block
from ..rules import (LINE_REPORT_REASONS, DEEP_DEPTH_SCORE, FIRST_STAGE_STARS, STAGE_NAMES, STAR_FLOAT_COST, SUPERNOVA_STARLIGHT,
                     PRISM_VERSION, UNLIT_PER_DAY, growth_stage)
from ..security import Cipher
from ..views import aware, iso, local, shared_star_ids, star_view
from ..ratelimit import per_user

router = APIRouter(prefix="/v1", tags=["stars"])

Mood = Literal["calm", "sorrow", "anger", "insight"]


class StarIn(BaseModel):
    mood: Mood | None = None
    # 17.5 감정 여러 개: the first is the star's colour. Given both, `moods` wins.
    moods: list[Mood] | None = Field(None, min_length=1, max_length=4)
    title: str = Field("", max_length=60)
    body: str = Field(..., min_length=1, max_length=20000)
    # 17.1 lit 별빛 받고 띄우기 | unlit 별빛 없이 띄우기. float and keep (before 20261109) mean the same.
    mode: Literal["lit", "unlit", "float", "keep"]
    # 14 다시 쓰기 / 11.2 고쳐 쓰기: the star this one rewrites; the two are linked (별 잇기).
    rewrite_of: str | None = None
    # 11.5 새 글을 써서 잇기: my stars to link the new one to (not a rewrite).
    link_to: list[str] = Field(default_factory=list, max_length=200)


class StarEdit(BaseModel):
    """Only what is given changes. Body and moods only while the star has no starlight (11.2)."""
    mood: Mood | None = None
    moods: list[Mood] | None = Field(None, min_length=1, max_length=4)
    title: str | None = Field(None, max_length=60)
    body: str | None = Field(None, min_length=1, max_length=20000)


class DraftIn(BaseModel):
    mood: Mood = "calm"
    moods: list[Mood] | None = Field(None, min_length=1, max_length=4)
    title: str = Field("", max_length=60)
    body: str = Field("", max_length=20000)
    source_star_id: str | None = None  # 11.2 고쳐 쓰기: the star being rewritten


class LinksIn(BaseModel):
    star_ids: list[str] = Field(..., min_length=1, max_length=200)


def _moods(mood: str | None, moods: list[str] | None) -> list[str] | None:
    if moods:
        return list(dict.fromkeys(moods))
    return [mood] if mood else None


def owned_star(db: Session, user: User, star_id: str) -> Star:
    star = db.get(Star, star_id)
    if star is None or star.user_id != user.id:
        raise ApiError(404, "not_found", "별을 찾지 못했어요.")
    return star


def _apply(star: Star, analysis: dict, cipher: Cipher) -> None:
    star.state = "floated"
    star.floated_at = now()
    analysis["starlight"] = max(1, analysis["starlight"])  # 17.3: a lit star has at least 1
    star.prism_version = PRISM_VERSION
    star.starlight = analysis["starlight"]
    star.depth_score = analysis["scores"]["depth"]
    star.analysis_enc = cipher.enc_json(analysis)
    star.analysis_failed = False


def _insufficient(user: User, cost: int) -> ApiError:
    return ApiError(402, "insufficient_coins", "코인이 조금 부족해요.", coins=user.coins, cost=cost)


def _float(db: Session, user: User, star: Star, request: Request, cipher: Cipher) -> tuple[str, int]:
    """Runs the prism on a star. Returns (prism status, coins charged); raises on unscoreable text.
    The day's free float first, then STAR_FLOAT_COST; charged only when the star is read."""
    settings = request.app.state.settings
    per_day = settings.free_stars_per_day
    member = membership.is_member(db, settings, user) and membership.left_today(user, "star") > 0
    free = member or allowance.stars_left(user, per_day) > 0
    if not free and user.coins < STAR_FLOAT_COST:
        raise _insufficient(user, STAR_FLOAT_COST)  # 29, before anything is stored
    with ai_cost.metered(db, user, "prism"):
        result = request.app.state.prism.evaluate(cipher.dec(star.title_enc), cipher.dec(star.body_enc))
    if result.status in ("too_short", "foul"):
        raise ApiError(422, result.status, result.message)
    if result.status == "failed":
        star.analysis_failed = True
        return result.status, 0
    if result.status != "ok":
        return result.status, 0
    charged = 0
    # A member's daily ones first, then the free one everybody has, then coins.
    used_free = (member and membership.use_today(db, user, "star")) or (free and allowance.use_star(db, user, per_day))
    if not used_free:
        if not coins.spend(db, user, STAR_FLOAT_COST, "별 띄우기"):
            db.rollback()
            raise _insufficient(user, STAR_FLOAT_COST)
        charged = STAR_FLOAT_COST
    _apply(star, result.analysis, cipher)
    return result.status, charged


def _response(db: Session, star: Star, cipher: Cipher, crisis: bool, charged: int = 0) -> dict:
    user = db.get(User, star.user_id)
    out = {"star": star_view(star, cipher, shared=star.id in shared_star_ids(db, star.user_id)),
           "crisis": CRISIS_GUIDANCE if crisis else None, "charged": charged, "coins": user.coins}
    if star.rewrite_of:
        prev = db.get(Star, star.rewrite_of)
        # 16 같은 마음, 다른 빛
        out["compare"] = {"previous_starlight": prev.starlight if prev else None, "starlight": star.starlight}
    return out


@router.post("/stars", status_code=201, dependencies=[per_user("prism", 30, 3600)])
def create_star(body: StarIn, request: Request, user: User = Depends(consented_user),
                db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """05 별 만들기. lit: read by the prism and priced as before. unlit: no model, free,
    UNLIT_PER_DAY a Korean day (429 unlit_daily_limit). A crisis signal: saved unlit, never read
    or charged (37). With `rewrite_of`, the new star is linked to the one it rewrites."""
    if body.rewrite_of:
        owned_star(db, user, body.rewrite_of)
    links = list(dict.fromkeys(body.link_to))
    if links and len(set(db.scalars(select(Star.id).where(Star.id.in_(links), Star.user_id == user.id)))) != len(links):
        raise ApiError(422, "invalid_stars", "이을 수 없는 별이 있어요.")
    moods = _moods(body.mood, body.moods)
    if not moods:
        raise ApiError(422, "mood_required", "기분을 하나 골라 주세요.")
    lit = body.mode in ("lit", "float")
    title = body.title.strip() or "제목 없는 별"
    star = Star(user_id=user.id, mood=moods[0], moods=moods, title_enc=cipher.enc(title),
                body_enc=cipher.enc(body.body), state="kept", rewrite_of=body.rewrite_of)
    # 37 위기 돌봄: the writing is always saved as written, but never scored.
    crisis = has_crisis_signal(f"{title}\n{body.body}")
    star.crisis = crisis
    charged = 0
    if lit and not crisis:
        _, charged = _float(db, user, star, request, cipher)  # 402/422 before anything is stored
    elif not lit and not allowance.use_unlit(db, user, UNLIT_PER_DAY):
        raise ApiError(429, "unlit_daily_limit", f"별빛 없이 띄우기는 하루 {UNLIT_PER_DAY}개까지예요.",
                       limit=UNLIT_PER_DAY)
    db.add(star)
    draft = db.get(Draft, user.id)
    # 11.2 고쳐 쓰기: from `rewrite_of`, or from the draft that was filled with the original.
    source = body.rewrite_of or (draft.source_star_id if draft and not links else None)
    db.flush()
    if source and db.get(Star, source) is not None:
        star.rewrite_of = source
        _link(db, user, star.id, source)
    for other in links:
        _link(db, user, star.id, other)
    # The draft goes when it is this writing's: a rewrite's draft with the rewrite, a plain one otherwise.
    if draft and draft.source_star_id == (source if source else None):
        db.delete(draft)
    db.commit()
    return _response(db, star, cipher, crisis, charged)


@router.post("/stars/{star_id}/starlight", dependencies=[per_user("prism", 30, 3600)])
def light_star(star_id: str, request: Request, user: User = Depends(consented_user),
               db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """17.1 나중에 별빛 받기, priced like a new lit star; 36 다시 시도 too. The writing is locked after."""
    star = owned_star(db, user, star_id)
    if star.state == "floated":
        raise ApiError(409, "already_lit", "이미 별빛을 받은 별이에요.")
    return _light(db, user, star, request, cipher)


@router.post("/stars/{star_id}/float", dependencies=[per_user("prism", 30, 3600)])
def float_star(star_id: str, request: Request, user: User = Depends(consented_user),
               db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """Before 20261109: POST /v1/stars/{id}/starlight, with its old 409 code."""
    star = owned_star(db, user, star_id)
    if star.state == "floated":
        raise ApiError(409, "already_floated", "이미 떠 있는 별이에요.")
    return _light(db, user, star, request, cipher)


def _light(db: Session, user: User, star: Star, request: Request, cipher: Cipher) -> dict:
    if star.crisis:
        return _response(db, star, cipher, crisis=True)
    status, charged = _float(db, user, star, request, cipher)
    share = db.scalar(select(StarShare).where(StarShare.star_id == star.id))
    if share is not None and star.state == "floated":  # shared before its starlight: now with its reading
        a = cipher.dec_json(star.analysis_enc)
        share.moods, share.depth_level, share.shape = [m["mood"] for m in a["moods"]], a["depth_level"], a["shape"]
    db.commit()
    if status == "failed":
        raise ApiError(502, "analysis_failed", "별을 읽지 못했어요. 글은 그대로 보관돼요.")
    return _response(db, star, cipher, crisis=False, charged=charged)


@router.get("/stars")
def list_stars(
    user: User = Depends(consented_user),
    db: Session = Depends(get_db),
    cipher: Cipher = Depends(get_cipher),
    state: Literal["floated", "kept"] | None = None,
    starlight: Literal["lit", "unlit"] | None = Query(None, description="17.1 별빛 받은 별 | 별빛 없는 별"),
    mood: Mood | None = Query(None, description="any of the star's moods"),
    q: str | None = Query(None, max_length=50, description="117 제목 · 본문 검색"),
    month: str | None = Query(None, pattern=r"^\d{4}-\d{2}$", description="YYYY-MM, Korean time"),
    before: datetime | None = None,
    limit: int = Query(50, ge=1, le=200),
):
    stmt = select(Star).where(Star.user_id == user.id).order_by(Star.created_at.desc())
    if starlight:
        state = "floated" if starlight == "lit" else "kept"
    if state:
        stmt = stmt.where(Star.state == state)
    if before:
        stmt = stmt.where(Star.created_at < before)
    shared = shared_star_ids(db, user.id)
    items = []
    # Titles and bodies are encrypted, so search and month filtering happen here.
    for star in db.scalars(stmt):
        if month and local(star.created_at).strftime("%Y-%m") != month:
            continue
        if mood and mood not in (star.moods or [star.mood]):
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
    """12 별 상세, with `linked_stars` (11.5 별 잇기)."""
    star = owned_star(db, user, star_id)
    return star_view(star, cipher, shared=star.id in shared_star_ids(db, user.id)) | {
        "linked_stars": _linked(db, star, cipher),
        "telescope": _telescope(db, star, cipher),
        "line_count": db.scalar(select(func.count()).select_from(_lines_query(db, user, star).subquery()))}


def _telescope(db: Session, star: Star, cipher: Cipher) -> dict | None:
    """11.5: the latest 마음 망원경 result of this star alone, shown inside its detail."""
    for r in db.scalars(select(TelescopeReport).where(TelescopeReport.user_id == star.user_id)
                        .order_by(TelescopeReport.created_at.desc())):
        if r.star_ids == [star.id]:
            return {"id": r.id, "created_at": iso(r.created_at), "report": cipher.dec_json(r.report_enc)}
    return None


def _link(db: Session, user: User, a: str, b: str) -> bool:
    a, b = sorted((a, b))
    if a == b or db.scalar(select(StarLink.id).where(StarLink.star_a == a, StarLink.star_b == b)):
        return False
    db.add(StarLink(user_id=user.id, star_a=a, star_b=b))
    db.flush()
    return True


def _linked(db: Session, star: Star, cipher: Cipher) -> list[dict]:
    ids = [b if a == star.id else a for a, b in db.execute(
        select(StarLink.star_a, StarLink.star_b).where(or_(StarLink.star_a == star.id, StarLink.star_b == star.id)))]
    stars = db.scalars(select(Star).where(Star.id.in_(ids)).order_by(Star.created_at)).all()
    return [{"id": s.id, "title": cipher.dec(s.title_enc), "created_at": iso(s.created_at), "mood": s.mood,
             "moods": s.moods or [s.mood], "has_starlight": s.state == "floated"} for s in stars]


class LineReportIn(BaseModel):
    reason: Literal[LINE_REPORT_REASONS]  # type: ignore[valid-type]
    block: bool = False


def _lines_query(db: Session, user: User, star: Star):
    return select(StarLine).where(StarLine.star_id == star.id, StarLine.hidden.is_(False),
                                  StarLine.user_id.not_in(hidden_users(db, user.id)))


@router.get("/stars/{star_id}/lines")
def star_lines(star_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """10.1 the 별빛 한 줄 left on my star, newest first: only I read them, and only I know how many."""
    star = owned_star(db, user, star_id)
    rows = db.scalars(_lines_query(db, user, star).order_by(StarLine.created_at.desc())).all()
    nicks = {i: n for i, n in db.execute(select(User.id, User.nickname).where(User.id.in_({r.user_id for r in rows})))}
    return {"items": [{"id": r.id, "text": r.text, "chip": r.chip, "nickname": nicks.get(r.user_id),
                       "created_at": iso(r.created_at)} for r in rows], "count": len(rows)}


@router.delete("/stars/{star_id}/lines/{line_id}", status_code=204)
def delete_star_line(star_id: str, line_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    star = owned_star(db, user, star_id)
    db.execute(delete(StarLine).where(StarLine.id == line_id, StarLine.star_id == star.id))
    db.commit()


@router.post("/stars/{star_id}/lines/{line_id}/report", dependencies=[per_user("report", 30, 3600)])
def report_star_line(star_id: str, line_id: str, body: LineReportIn, user: User = Depends(consented_user),
                     db: Session = Depends(get_db)):
    """The owner reports a line left on their star: it is hidden at once (only the owner ever saw it)."""
    star = owned_star(db, user, star_id)
    line = db.get(StarLine, line_id)
    if line is None or line.star_id != star.id:
        raise ApiError(404, "not_found", "별빛을 찾지 못했어요.")
    if db.get(StarLineReport, (line.id, user.id)) is None:
        db.add(StarLineReport(line_id=line.id, user_id=user.id, reason=body.reason))
    line.hidden = True
    blocked = False
    if body.block:
        block(db, user, "star_line", line.id)
        blocked = True
    db.commit()
    return {"reported": True, "blocked": blocked}


@router.post("/stars/{star_id}/links", dependencies=[per_user("links", 120, 3600)])
def add_links(star_id: str, body: LinksIn, user: User = Depends(consented_user), db: Session = Depends(get_db),
              cipher: Cipher = Depends(get_cipher)):
    """11.5 별 잇기: several of my stars at once. Already linked ones are left as they are."""
    star = owned_star(db, user, star_id)
    ids = list(dict.fromkeys(i for i in body.star_ids if i != star.id))
    found = set(db.scalars(select(Star.id).where(Star.id.in_(ids), Star.user_id == user.id)))
    if len(found) != len(ids) or not ids:
        raise ApiError(422, "invalid_stars", "이을 수 없는 별이 있어요.")
    added = sum(_link(db, user, star.id, other) for other in ids)
    db.commit()
    return {"added": added, "linked_stars": _linked(db, star, cipher)}


@router.delete("/stars/{star_id}/links/{other_id}", status_code=204)
def remove_link(star_id: str, other_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    owned_star(db, user, star_id)
    a, b = sorted((star_id, other_id))
    db.execute(delete(StarLink).where(StarLink.star_a == a, StarLink.star_b == b, StarLink.user_id == user.id))
    db.commit()


@router.patch("/stars/{star_id}", dependencies=[per_user("star_edit", 60, 3600)])
def edit_star(star_id: str, body: StarEdit, user: User = Depends(consented_user), db: Session = Depends(get_db),
              cipher: Cipher = Depends(get_cipher)):
    """글 수정 (11.2). A star without starlight: title, body and moods. A lit star is locked: title only;
    a different body or moods is 409 star_locked (고쳐 쓰기 makes a new star instead).
    The crisis check runs again: a new signal takes the star off the plaza (`share_removed`).
    A full-text share follows the new title and writing; if its 대표 문장 is gone from the writing,
    the sentence is cleared and `quote_missing` asks for another. A sentence-only share keeps the
    sentence copied when shared."""
    star = owned_star(db, user, star_id)
    moods = _moods(body.mood, body.moods)
    if star.state == "floated":
        if moods is not None and moods != (star.moods or [star.mood]) and moods != [star.mood]:
            raise ApiError(409, "star_locked", "별빛을 받은 별은 기분을 바꿀 수 없어요. 고쳐 쓰기로 새 별을 띄워 보세요.")
        if body.body is not None and body.body != cipher.dec(star.body_enc):
            raise ApiError(409, "star_locked", "별빛을 받은 별은 글을 바꿀 수 없어요. 고쳐 쓰기로 새 별을 띄워 보세요.")
        moods = None
    if body.body is not None and not body.body.strip():
        raise ApiError(422, "empty_body", "본문을 비울 수는 없어요.")
    if body.title is not None:
        star.title_enc = cipher.enc(body.title.strip() or "제목 없는 별")
    if body.body is not None:
        star.body_enc = cipher.enc(body.body)
    if moods is not None:
        star.mood, star.moods = moods[0], moods
    crisis = has_crisis_signal(f"{cipher.dec(star.title_enc)}\n{cipher.dec(star.body_enc)}")
    star.crisis = crisis
    star.updated_at = datetime.now(timezone.utc)
    share = db.scalar(select(StarShare).where(StarShare.star_id == star.id))
    removed = quote_missing = False
    if share is not None and crisis:
        db.delete(share)
        removed = True
    elif share is not None and share.full_text:
        body_masked = privacy.scan(cipher.dec(star.body_enc), "contacts")["masked"]
        share.name = privacy.scan(cipher.dec(star.title_enc), "contacts")["masked"]
        share.body_masked_enc = cipher.enc(body_masked)
        if share.quote and share.quote not in body_masked:
            share.quote = None
        quote_missing = share.quote is None
    db.commit()
    return _response(db, star, cipher, crisis) | {"share_removed": removed, "quote_missing": quote_missing}


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
    return {"mood": d.mood, "moods": d.moods or [d.mood], "title": cipher.dec(d.title_enc),
            "body": cipher.dec(d.body_enc), "source_star_id": d.source_star_id, "updated_at": iso(d.updated_at)}


@router.put("/drafts/current")
def save_draft(body: DraftIn, user: User = Depends(consented_user), db: Session = Depends(get_db),
               cipher: Cipher = Depends(get_cipher)):
    """34 임시 저장하고 나가기"""
    if body.source_star_id:
        owned_star(db, user, body.source_star_id)
    moods = _moods(body.mood, body.moods)
    d = db.get(Draft, user.id) or Draft(user_id=user.id)
    d.mood, d.moods, d.title_enc, d.body_enc = moods[0], moods, cipher.enc(body.title), cipher.enc(body.body)
    d.source_star_id = body.source_star_id
    db.add(d)
    db.commit()
    return {"saved": True, "updated_at": iso(aware(d.updated_at)) if d.updated_at else None}


@router.delete("/drafts/current", status_code=204)
def discard_draft(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    d = db.get(Draft, user.id)
    if d:
        db.delete(d)
        db.commit()
