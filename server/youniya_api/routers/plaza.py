"""우주 광장: 09/72 둘러보기, 19/20/55 별 나누기, 73/75 다른 이의 별·성운, 74 별빛 한 줄,
99–101 거절·신고, 69 모두의 은하. No scores, ranks or counts are shown to others."""

from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from .. import privacy
from ..deps import ApiError, consented_user, get_cipher, get_db
from ..models import Beside, LineReport, NebulaShare, Resonance, Star, StarlightLine, StarShare, User
from ..rules import LINE_LIFETIME_HOURS, LINE_MAX_LENGTH, LINE_REPORT_REASONS
from ..security import Cipher
from ..views import KST, iso
from .stars import owned_star

router = APIRouter(prefix="/v1", tags=["plaza"])

Kind = Literal["star", "nebula"]
_MODELS = {"star": StarShare, "nebula": NebulaShare}
# A line hidden for everyone once this many people report it.
HIDE_AFTER_REPORTS = 3


class ScanIn(BaseModel):
    text: str = Field(..., max_length=20000)


class StarShareIn(BaseModel):
    quote: str = Field(..., min_length=1, max_length=300)  # 75 본인이 골라 공개한 한 문장


class LineIn(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)


class ReportIn(BaseModel):
    reason: Literal[LINE_REPORT_REASONS]  # type: ignore[valid-type]


@router.post("/plaza/privacy-scan")
def privacy_scan(body: ScanIn, user: User = Depends(consented_user)):
    """20 공유 전 확인: "가려진 항목 2개 · 이름 1 · 장소 1"."""
    return privacy.scan(body.text)


@router.put("/stars/{star_id}/share")
def share_star(star_id: str, body: StarShareIn, user: User = Depends(consented_user),
               db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """19 익명으로 나누기. Only the chosen sentence goes out, masked; the rest of the writing stays."""
    star = owned_star(db, user, star_id)
    if star.state != "floated":
        raise ApiError(422, "not_floated", "떠 있는 별만 나눌 수 있어요.")
    if star.crisis:
        raise ApiError(422, "crisis", "지금은 나누지 않아도 괜찮아요.")
    if body.quote not in cipher.dec(star.body_enc):
        raise ApiError(422, "quote_not_found", "내가 쓴 문장 중에서 골라 주세요.")
    a = cipher.dec_json(star.analysis_enc)
    row = db.scalar(select(StarShare).where(StarShare.star_id == star.id)) or StarShare(
        star_id=star.id, user_id=user.id)
    row.name = privacy.scan(cipher.dec(star.title_enc))["masked"]
    row.quote = privacy.scan(body.quote)["masked"]
    row.mood, row.moods = star.mood, [m["mood"] for m in a["moods"]]
    row.depth_level, row.shape = a["depth_level"], a["shape"]
    db.add(row)
    db.commit()
    return {"share_id": row.id, "name": row.name, "quote": row.quote}


@router.delete("/stars/{star_id}/share", status_code=204)
def unshare_star(star_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    star = owned_star(db, user, star_id)
    db.execute(delete(StarShare).where(StarShare.star_id == star.id))
    db.commit()


def _marks(db: Session, user: User, kind: str) -> tuple[set[str], set[str]]:
    res = set(db.scalars(select(Resonance.target_id).where(Resonance.user_id == user.id, Resonance.kind == kind)))
    bes = set(db.scalars(select(Beside.target_id).where(Beside.user_id == user.id, Beside.kind == kind)))
    return res, bes


def _similar_order(db: Session, user: User, rows: list) -> list:
    """나와 결이 비슷한: shares whose moods match the moods I write in most."""
    profile: dict[str, int] = {}
    for mood in db.scalars(select(Star.mood).where(Star.user_id == user.id, Star.state == "floated")
                           .order_by(Star.created_at.desc()).limit(20)):
        profile[mood] = profile.get(mood, 0) + 1
    return sorted(rows, key=lambda r: (-sum(profile.get(m, 0) for m in r.moods), -r.created_at.timestamp()))


def _star_item(s: StarShare, res: set[str], bes: set[str]) -> dict:
    return {"id": s.id, "name": s.name, "quote": s.quote, "mood": s.mood, "moods": s.moods,
            "depth_level": s.depth_level, "shape": s.shape, "created_at": iso(s.created_at),
            "resonated": s.id in res, "beside": s.id in bes}


def _nebula_item(n: NebulaShare, res: set[str], bes: set[str]) -> dict:
    return {"id": n.id, "name": n.name, "quote": n.quote, "moods": n.moods, "depth_level": n.depth_level,
            "shape": n.shape, "receive_lines": n.receive_lines, "created_at": iso(n.created_at),
            "resonated": n.id in res, "beside": n.id in bes}


@router.get("/plaza/stars")
def plaza_stars(sort: Literal["new", "similar"] = "new", limit: int = Query(40, ge=1, le=100),
                user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """09 새로 뜬 것 · 나와 결이 비슷한"""
    rows = db.scalars(select(StarShare).where(StarShare.user_id != user.id)
                      .order_by(StarShare.created_at.desc()).limit(500)).all()
    if sort == "similar":
        rows = _similar_order(db, user, rows)
    res, bes = _marks(db, user, "star")
    return {"items": [_star_item(s, res, bes) for s in rows[:limit]]}


@router.get("/plaza/stars/{share_id}")
def plaza_star(share_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """75 다른 이의 별"""
    s = db.get(StarShare, share_id)
    if s is None:
        raise ApiError(404, "not_found", "별을 찾지 못했어요.")
    return _star_item(s, *_marks(db, user, "star"))


@router.get("/plaza/nebulae")
def plaza_nebulae(filter: Literal["similar", "new", "beside"] = "similar", limit: int = Query(40, ge=1, le=100),
                  user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """72 나와 비슷한 결 · 새로 띄운 성운 · 곁에 둔 성운"""
    res, bes = _marks(db, user, "nebula")
    stmt = select(NebulaShare).where(NebulaShare.user_id != user.id).order_by(NebulaShare.created_at.desc())
    if filter == "beside":
        stmt = stmt.where(NebulaShare.id.in_(bes))
    rows = db.scalars(stmt.limit(500)).all()
    if filter == "similar":
        rows = _similar_order(db, user, rows)
    return {"items": [_nebula_item(n, res, bes) for n in rows[:limit]]}


def _nebula_share(db: Session, share_id: str) -> NebulaShare:
    n = db.get(NebulaShare, share_id)
    if n is None:
        raise ApiError(404, "not_found", "성운을 찾지 못했어요.")
    return n


@router.get("/plaza/nebulae/{share_id}")
def plaza_nebula(share_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """73 다른 이의 성운"""
    return _nebula_item(_nebula_share(db, share_id), *_marks(db, user, "nebula"))


def _target(db: Session, user: User, kind: str, target_id: str):
    row = db.get(_MODELS[kind], target_id)
    if row is None:
        raise ApiError(404, "not_found", "찾지 못했어요.")
    if row.user_id == user.id:
        raise ApiError(422, "own_share", "내가 나눈 것이에요.")
    return row


def _toggle(table, on: bool, kind: str, target_id: str, user: User, db: Session) -> dict:
    _target(db, user, kind, target_id)
    exists = db.get(table, (user.id, kind, target_id))
    if on and not exists:
        db.add(table(user_id=user.id, kind=kind, target_id=target_id))
    elif not on and exists:
        db.delete(exists)
    db.commit()
    return {"on": on}


@router.put("/plaza/{kind}/{target_id}/resonance")
def resonate(kind: Kind, target_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """공명 남기기"""
    return _toggle(Resonance, True, kind, target_id, user, db)


@router.delete("/plaza/{kind}/{target_id}/resonance")
def unresonate(kind: Kind, target_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    return _toggle(Resonance, False, kind, target_id, user, db)


@router.put("/plaza/{kind}/{target_id}/beside")
def keep_beside(kind: Kind, target_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """곁에 두기: it shows in my 컬렉션 (79, 80)."""
    return _toggle(Beside, True, kind, target_id, user, db)


@router.delete("/plaza/{kind}/{target_id}/beside")
def drop_beside(kind: Kind, target_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    return _toggle(Beside, False, kind, target_id, user, db)


def _line_cutoff() -> datetime:
    return datetime.now(timezone.utc) - timedelta(hours=LINE_LIFETIME_HOURS)


@router.get("/plaza/nebulae/{share_id}/lines")
def lines(share_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """74: lines from the last day, newest first. Lines I reported are hidden from me at once."""
    share = _nebula_share(db, share_id)
    reported = select(LineReport.line_id).where(LineReport.user_id == user.id)
    rows = db.scalars(select(StarlightLine).where(
        StarlightLine.share_id == share.id, StarlightLine.created_at >= _line_cutoff(),
        StarlightLine.hidden.is_(False), StarlightLine.id.not_in(reported),
    ).order_by(StarlightLine.created_at.desc())).all()
    mine = db.scalar(select(StarlightLine.id).where(StarlightLine.share_id == share.id,
                                                   StarlightLine.user_id == user.id))
    return {"items": [{"id": r.id, "text": r.text, "created_at": iso(r.created_at), "mine": r.user_id == user.id}
                      for r in rows],
            "can_leave": share.receive_lines and mine is None and share.user_id != user.id,
            "max_length": LINE_MAX_LENGTH}


@router.post("/plaza/nebulae/{share_id}/lines", status_code=201)
def leave_line(share_id: str, body: LineIn, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    share = _nebula_share(db, share_id)
    if share.user_id == user.id:
        raise ApiError(422, "own_share", "내가 띄운 성운이에요.")
    if not share.receive_lines:
        raise ApiError(403, "lines_closed", "별빛 한 줄을 받지 않는 성운이에요.")
    text = body.text.strip()
    if len(text) > LINE_MAX_LENGTH:  # 106
        raise ApiError(422, "too_long", f"{LINE_MAX_LENGTH}자 안으로 줄여 주세요.", length=len(text),
                       max_length=LINE_MAX_LENGTH)
    if privacy.is_hurtful(text):  # 99
        raise ApiError(422, "hurtful", "상처가 될 수 있는 말이 있어 띄우지 못했어요.")
    if db.scalar(select(StarlightLine.id).where(StarlightLine.share_id == share.id,
                                               StarlightLine.user_id == user.id)):  # 107
        raise ApiError(409, "already_left", "이 성운에는 이미 한 줄을 남겼어요.")
    row = StarlightLine(share_id=share.id, user_id=user.id, text=privacy.scan(text)["masked"])
    db.add(row)
    db.commit()
    return {"id": row.id, "text": row.text, "created_at": iso(row.created_at), "mine": True}


@router.post("/plaza/lines/{line_id}/report")
def report_line(line_id: str, body: ReportIn, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """100 신고하기 → 101 신고를 받았어요. The reporter is never told to anyone."""
    line = db.get(StarlightLine, line_id)
    if line is None:
        raise ApiError(404, "not_found", "별빛을 찾지 못했어요.")
    if db.get(LineReport, (line.id, user.id)) is None:
        db.add(LineReport(line_id=line.id, user_id=user.id, reason=body.reason))
        db.flush()
        count = db.scalar(select(func.count()).select_from(LineReport).where(LineReport.line_id == line.id))
        if count >= HIDE_AFTER_REPORTS:
            line.hidden = True
        db.commit()
    return {"reported": True}


@router.get("/plaza/tonight")
def tonight(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """69 오늘 밤, N개의 마음이 모였어요: every star floated today (Korean time), no writing."""
    start = datetime.now(KST).replace(hour=0, minute=0, second=0, microsecond=0).astimezone(timezone.utc)
    floated_today = select(func.count()).select_from(Star).where(Star.state == "floated", Star.created_at >= start)
    return {"count": db.scalar(floated_today),
            "mine": db.scalar(floated_today.where(Star.user_id == user.id))}
