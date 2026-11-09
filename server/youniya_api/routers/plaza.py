"""우주 광장: 09/72 둘러보기, 19/20/55 별 나누기, 73/75 다른 이의 별·성운, 74 별빛 한 줄,
99–101 거절·신고, 69 모두의 은하. No scores, ranks or counts are shown to others."""

from datetime import datetime, timedelta, timezone
from typing import Literal

import logging

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from .. import nickname, privacy
from ..push import Message, notify
from ..blocks import can_see, hidden_users, visible_shares
from ..deps import ApiError, consented_user, get_cipher, get_db, plaza_user
from ..models import AdminLog, Beside, StarLine, LineReport, NebulaShare, Resonance, ShareReport, Star, StarlightLine, StarShare, User
from ..rules import LINE_CHIPS, LINE_LIFETIME_HOURS, LINE_MAX_LENGTH, LINE_REPORT_REASONS
from ..security import Cipher
from ..views import KST, iso
from ..ratelimit import per_user
from .blocks import block
from .stars import owned_star

router = APIRouter(prefix="/v1", tags=["plaza"])
log = logging.getLogger(__name__)

Kind = Literal["star", "nebula"]
_MODELS = {"star": StarShare, "nebula": NebulaShare}
# A line hidden for everyone once this many people report it.
HIDE_AFTER_REPORTS = 3
# 18.3: these take a share down at the first report, and tell the operators.
URGENT_REASONS = ("personal_info", "self_harm")


def _alert_operators(db: Session, request: Request, kind: str, target_id: str, reason: str) -> None:
    """A log line (it reaches Sentry), an AdminLog, and a push to OPERATOR_USER_IDS' devices."""
    log.error("urgent report: %s %s (%s) hidden at the first report", kind, target_id, reason)
    db.add(AdminLog(action=f"urgent_report_{kind}", target_id=target_id))
    settings = request.app.state.settings
    if settings.operator_user_ids:
        notify(db, request.app.state.push, list(settings.operator_user_ids),
               Message(title="바로 숨긴 신고가 있어요", body="개인정보 또는 위기 관련 신고예요. 관리 화면에서 살펴봐 주세요."))


class ScanIn(BaseModel):
    text: str = Field(..., max_length=20000)
    mode: Literal["all", "contacts"] = "all"  # "contacts": how a star's whole writing is masked


class StarShareIn(BaseModel):
    quote: str = Field(..., min_length=1, max_length=300)  # 75 대표 문장, one the owner wrote
    # The owner agreed that the title and the whole writing go out too (contacts masked).
    # Without it, as before: the chosen sentence only.
    full_text: bool = False
    receive_lines: bool = True  # 10.1 별빛 한 줄 받기


class LineIn(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)


class ReportIn(BaseModel):
    reason: Literal[LINE_REPORT_REASONS]  # type: ignore[valid-type]
    block: bool = False  # 100 "이 별지기도 차단하기"


@router.post("/plaza/privacy-scan", dependencies=[per_user("scan", 60, 60)])
def privacy_scan(body: ScanIn, user: User = Depends(consented_user)):
    """20 공유 전 확인: "가려진 항목 2개 · 이름 1 · 장소 1"."""
    return privacy.scan(body.text, body.mode)


@router.put("/stars/{star_id}/share")
def share_star(star_id: str, body: StarShareIn, user: User = Depends(plaza_user),
               db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """19 익명으로 나누기. With `full_text`, the title and the whole writing go out with the chosen
    sentence as its 대표 문장, only contacts and identifying numbers masked (names and places stay).
    Without it, only the chosen sentence goes out, with names and places masked too."""
    star = owned_star(db, user, star_id)
    if star.crisis:
        raise ApiError(422, "crisis", "지금은 나누지 않아도 괜찮아요.")
    if body.quote not in cipher.dec(star.body_enc):
        raise ApiError(422, "quote_not_found", "내가 쓴 문장 중에서 골라 주세요.")
    # 17.2: a star without starlight can be shared too; it has no reading, so a plain shape.
    a = cipher.dec_json(star.analysis_enc) if star.state == "floated" else {
        "moods": [{"mood": m} for m in (star.moods or [star.mood])], "depth_level": 0,
        "shape": {"points": 3, "sharpness": "soft"}}
    row = db.scalar(select(StarShare).where(StarShare.star_id == star.id)) or StarShare(
        star_id=star.id, user_id=user.id)
    mode = "contacts" if body.full_text else "all"
    row.name = privacy.scan(cipher.dec(star.title_enc), mode)["masked"]
    row.quote = privacy.scan(body.quote, mode)["masked"]
    row.full_text = body.full_text
    row.receive_lines = body.receive_lines
    row.body_masked_enc = cipher.enc(privacy.scan(cipher.dec(star.body_enc), mode)["masked"]) if body.full_text else None
    row.mood, row.moods = star.mood, [m["mood"] for m in a["moods"]]
    row.depth_level, row.shape = a["depth_level"], a["shape"]
    db.add(row)
    db.commit()
    return {"share_id": row.id, "name": row.name, "quote": row.quote, "full_text": row.full_text,
            "receive_lines": row.receive_lines}


@router.delete("/stars/{star_id}/share", status_code=204)
def unshare_star(star_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    star = owned_star(db, user, star_id)
    db.execute(delete(StarShare).where(StarShare.star_id == star.id))
    db.commit()


def _marks(db: Session, user: User, kind: str) -> tuple[set[str], set[str]]:
    res = set(db.scalars(select(Resonance.target_id).where(Resonance.user_id == user.id, Resonance.kind == kind)))
    bes = set(db.scalars(select(Beside.target_id).where(Beside.user_id == user.id, Beside.kind == kind)))
    return res, bes


def _besides_first(db: Session, user: User, model, kind: str):
    """곁에 둔 것: my besides of this kind, the most recently kept first."""
    return (select(model).join(Beside, (Beside.target_id == model.id) & (Beside.kind == kind)
                               & (Beside.user_id == user.id))
            .where(model.user_id != user.id, *visible_shares(db, user.id, model))
            .order_by(Beside.created_at.desc()))


def _similar_order(db: Session, user: User, rows: list) -> list:
    """나와 결이 비슷한: shares whose moods match the moods I write in most."""
    profile: dict[str, int] = {}
    for mood in db.scalars(select(Star.mood).where(Star.user_id == user.id, Star.state == "floated")
                           .order_by(Star.created_at.desc()).limit(20)):
        profile[mood] = profile.get(mood, 0) + 1
    return sorted(rows, key=lambda r: (-sum(profile.get(m, 0) for m in r.moods), -r.created_at.timestamp()))


def _left(db: Session, user: User, rows) -> set[str]:
    ids = [r.star_id for r in rows]
    return set(db.scalars(select(StarLine.star_id).where(StarLine.user_id == user.id, StarLine.star_id.in_(ids))))


def _nicks(db: Session, rows) -> dict[str, str | None]:
    ids = {r.user_id for r in rows}
    return {i: n for i, n in db.execute(select(User.id, User.nickname).where(User.id.in_(ids)))} if ids else {}


def _star_item(s: StarShare, res: set[str], bes: set[str], nicks: dict | None = None,
               left: set[str] | None = None) -> dict:
    """The list item: the 대표 문장, never the writing (75 has it). `nickname`: the 별지기 이름 (15장).
    `receive_lines` and `line_left` (I already left my 별빛 한 줄 on this star): 10.1."""
    return {"id": s.id, "name": s.name, "nickname": (nicks or {}).get(s.user_id), "quote": s.quote, "mood": s.mood, "moods": s.moods,
            "depth_level": s.depth_level, "shape": s.shape, "created_at": iso(s.created_at),
            "full_text": s.full_text, "has_starlight": s.depth_level > 0,
            "receive_lines": s.receive_lines, "line_left": s.star_id in (left or set()),
            "resonated": s.id in res, "beside": s.id in bes}


def _nebula_item(n: NebulaShare, res: set[str], bes: set[str]) -> dict:
    return {"id": n.id, "name": n.name, "quote": n.quote, "moods": n.moods, "depth_level": n.depth_level,
            "shape": n.shape, "receive_lines": n.receive_lines, "created_at": iso(n.created_at),
            "resonated": n.id in res, "beside": n.id in bes}


@router.get("/plaza/stars")
def plaza_stars(sort: Literal["new", "similar", "beside"] = "new", limit: int = Query(40, ge=1, le=100),
                user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """09 새로 뜬 것 · 나와 결이 비슷한 · 곁에 둔 것 (the most recently kept first)"""
    stmt = (_besides_first(db, user, StarShare, "star") if sort == "beside" else
            select(StarShare).where(StarShare.user_id != user.id, *visible_shares(db, user.id, StarShare))
            .order_by(StarShare.created_at.desc()))
    # A star whose 대표 문장 an edit took out waits off the plaza until one is picked again:
    # builds before 20261108 cannot read a share without one.
    stmt = stmt.where(StarShare.quote.is_not(None))
    rows = db.scalars(stmt.limit(500)).all()
    # 17.2: stars without starlight (depth_level 0) come after the lit ones, and not among the similar.
    if sort == "similar":
        rows = _similar_order(db, user, [r for r in rows if r.depth_level > 0])
    elif sort == "new":
        rows = sorted(rows, key=lambda r: r.depth_level == 0)
    res, bes = _marks(db, user, "star")
    rows = rows[:limit]
    nicks, left = _nicks(db, rows), _left(db, user, rows)
    return {"items": [_star_item(s, res, bes, nicks, left) for s in rows]}


@router.get("/plaza/stars/{share_id}")
def plaza_star(share_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db),
               cipher: Cipher = Depends(get_cipher)):
    """75 다른 이의 별. A full-text share adds the title and writing as shared (contacts masked);
    one shared before 20261108 or without that agreement still shows only its sentence."""
    s = db.get(StarShare, share_id)
    if s is None or s.quote is None or not can_see(db, user.id, s):
        raise ApiError(404, "not_found", "별을 찾지 못했어요.")
    full = s.full_text and s.body_masked_enc
    return _star_item(s, *_marks(db, user, "star"), _nicks(db, [s]), _left(db, user, [s])) | {
        "title_masked": s.name if full else None, "body_masked": cipher.dec(s.body_masked_enc) if full else None}


@router.get("/plaza/nebulae")
def plaza_nebulae(filter: Literal["similar", "new", "beside"] = "similar", limit: int = Query(40, ge=1, le=100),
                  user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """72 나와 비슷한 결 · 새로 띄운 성운 · 곁에 둔 성운 (the most recently kept first)"""
    res, bes = _marks(db, user, "nebula")
    stmt = (_besides_first(db, user, NebulaShare, "nebula") if filter == "beside" else
            select(NebulaShare).where(NebulaShare.user_id != user.id, *visible_shares(db, user.id, NebulaShare))
            .order_by(NebulaShare.created_at.desc()))
    rows = db.scalars(stmt.limit(500)).all()
    if filter == "similar":
        rows = _similar_order(db, user, rows)
    return {"items": [_nebula_item(n, res, bes) for n in rows[:limit]]}


def _nebula_share(db: Session, share_id: str, user: User) -> NebulaShare:
    n = db.get(NebulaShare, share_id)
    if n is None or (n.user_id != user.id and not can_see(db, user.id, n)):
        raise ApiError(404, "not_found", "성운을 찾지 못했어요.")
    return n


@router.get("/plaza/nebulae/{share_id}")
def plaza_nebula(share_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """73 다른 이의 성운"""
    return _nebula_item(_nebula_share(db, share_id, user), *_marks(db, user, "nebula"))


def _target(db: Session, user: User, kind: str, target_id: str):
    row = db.get(_MODELS[kind], target_id)
    if row is None or (row.user_id != user.id and not can_see(db, user.id, row)):
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
def resonate(kind: Kind, target_id: str, user: User = Depends(plaza_user), db: Session = Depends(get_db)):
    """공명 남기기"""
    return _toggle(Resonance, True, kind, target_id, user, db)


@router.delete("/plaza/{kind}/{target_id}/resonance")
def unresonate(kind: Kind, target_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    return _toggle(Resonance, False, kind, target_id, user, db)


@router.put("/plaza/{kind}/{target_id}/beside")
def keep_beside(kind: Kind, target_id: str, user: User = Depends(plaza_user), db: Session = Depends(get_db)):
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
    share = _nebula_share(db, share_id, user)
    reported = select(LineReport.line_id).where(LineReport.user_id == user.id)
    rows = db.scalars(select(StarlightLine).where(
        StarlightLine.share_id == share.id, StarlightLine.created_at >= _line_cutoff(),
        StarlightLine.hidden.is_(False), StarlightLine.id.not_in(reported),
        StarlightLine.user_id.not_in(hidden_users(db, user.id)),
    ).order_by(StarlightLine.created_at.desc())).all()
    mine = db.scalar(select(StarlightLine.id).where(StarlightLine.share_id == share.id,
                                                   StarlightLine.user_id == user.id))
    return {"items": [{"id": r.id, "text": r.text, "created_at": iso(r.created_at), "mine": r.user_id == user.id}
                      for r in rows],
            "can_leave": share.receive_lines and mine is None and share.user_id != user.id,
            "max_length": LINE_MAX_LENGTH}


@router.post("/plaza/nebulae/{share_id}/lines", status_code=201, dependencies=[per_user("lines", 30, 3600)])
def leave_line(share_id: str, body: LineIn, user: User = Depends(plaza_user), db: Session = Depends(get_db)):
    share = _nebula_share(db, share_id, user)
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


@router.post("/plaza/lines/{line_id}/report", dependencies=[per_user("report", 30, 3600)])
def report_line(line_id: str, body: ReportIn, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """100 신고하기 → 101 신고를 받았어요. The reporter is never told to anyone."""
    line = db.get(StarlightLine, line_id)
    if line is None:
        raise ApiError(404, "not_found", "별빛을 찾지 못했어요.")
    blocked = False
    if body.block and line.user_id != user.id:
        block(db, user, "line", line.id)
        blocked = True
    if db.get(LineReport, (line.id, user.id)) is None:
        db.add(LineReport(line_id=line.id, user_id=user.id, reason=body.reason))
        db.flush()
        count = db.scalar(select(func.count()).select_from(LineReport).where(LineReport.line_id == line.id))
        if count >= HIDE_AFTER_REPORTS or body.reason in URGENT_REASONS:
            line.hidden = True
    db.commit()
    return {"reported": True, "blocked": blocked}


@router.post("/plaza/{kind}/{target_id}/report", dependencies=[per_user("report", 30, 3600)])
def report_share(kind: Kind, target_id: str, body: ReportIn, request: Request, user: User = Depends(consented_user),
                 db: Session = Depends(get_db)):
    """100 신고하기 for a plaza star or nebula. It leaves the reporter's plaza at once; three reports
    take it down for everyone until an operator looks. 18.3: personal_info or self_harm takes it down
    at the first report, and the operators hear of it at once."""
    row = _target(db, user, kind, target_id)
    blocked = False
    if body.block:
        block(db, user, kind, target_id)
        blocked = True
    if db.get(ShareReport, (kind, target_id, user.id)) is None:
        db.add(ShareReport(kind=kind, target_id=target_id, user_id=user.id, reason=body.reason))
        db.flush()
        count = db.scalar(select(func.count()).select_from(ShareReport)
                          .where(ShareReport.kind == kind, ShareReport.target_id == target_id))
        urgent = body.reason in URGENT_REASONS
        if (urgent or count >= HIDE_AFTER_REPORTS) and not row.hidden:
            row.hidden = True
            if urgent:
                _alert_operators(db, request, kind, target_id, body.reason)
    db.commit()
    return {"reported": True, "blocked": blocked}


class StarLineIn(BaseModel):
    text: str | None = Field(None, max_length=500)
    chip: Literal[tuple(LINE_CHIPS)] | None = None  # type: ignore[valid-type]  # 빠른 공감 instead of words


@router.post("/plaza/stars/{share_id}/lines", status_code=201, dependencies=[per_user("lines", 30, 3600)])
def leave_star_line(share_id: str, body: StarLineIn, user: User = Depends(plaza_user),
                    db: Session = Depends(get_db)):
    """10.1 별빛 한 줄 on someone's shared star: words (60 characters) or a 빠른 공감 chip. One per person
    per star. Only the owner reads it; it stays, even after the star leaves the plaza."""
    s = db.get(StarShare, share_id)
    if s is None or s.quote is None or not can_see(db, user.id, s):
        raise ApiError(404, "not_found", "별을 찾지 못했어요.")
    if s.user_id == user.id:
        raise ApiError(422, "own_share", "내가 나눈 별이에요.")
    if not s.receive_lines:
        raise ApiError(403, "lines_closed", "별빛 한 줄을 받지 않는 별이에요.")
    text = LINE_CHIPS[body.chip] if body.chip else (body.text or "").strip()
    if not text:
        raise ApiError(422, "empty_line", "한 줄을 적어 주세요.")
    if len(text) > LINE_MAX_LENGTH:  # 106
        raise ApiError(422, "too_long", f"{LINE_MAX_LENGTH}자 안으로 줄여 주세요.", length=len(text),
                       max_length=LINE_MAX_LENGTH)
    if not body.chip and (why := privacy.line_problem(text)):
        raise ApiError(422, why, LINE_REFUSALS[why])
    if db.scalar(select(StarLine.id).where(StarLine.star_id == s.star_id, StarLine.user_id == user.id)):
        raise ApiError(409, "already_left", "이 별에는 이미 한 줄을 남겼어요.")
    row = StarLine(star_id=s.star_id, user_id=user.id, chip=body.chip, text=text)
    db.add(row)
    db.commit()
    return {"id": row.id, "text": row.text, "chip": row.chip, "created_at": iso(row.created_at)}


LINE_REFUSALS = {
    "hurtful": "상처가 될 수 있는 말이 있어 남기지 못했어요.",
    "contact": "연락처는 남길 수 없어요.",
    "judging": "판단하는 말 대신 마음을 남겨 주세요.",
    "advice": "조언 대신 마음을 남겨 주세요.",
}


@router.get("/keepers/{name}")
def keeper(name: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """15장 별지기 페이지: only the stars this keeper shared, newest first. No counts, no starlight
    numbers, nothing unshared. A keeper blocked either way is not found."""
    owner = db.scalar(select(User).where(User.nickname_key == nickname.key(name)))
    if owner is None or owner.id in hidden_users(db, user.id):
        raise ApiError(404, "not_found", "별지기를 찾지 못했어요.")
    rows = db.scalars(select(StarShare).where(StarShare.user_id == owner.id, StarShare.quote.is_not(None),
                                              *visible_shares(db, user.id, StarShare))
                      .order_by(StarShare.created_at.desc()).limit(200)).all()
    res, bes = _marks(db, user, "star")
    return {"nickname": owner.nickname, "mine": owner.id == user.id,
            "items": [_star_item(s, res, bes, {owner.id: owner.nickname}) for s in rows]}


@router.get("/plaza/tonight")
def tonight(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """69 오늘 밤, N개의 마음이 모였어요: every star floated today (Korean time), no writing."""
    start = datetime.now(KST).replace(hour=0, minute=0, second=0, microsecond=0).astimezone(timezone.utc)
    floated_today = select(func.count()).select_from(Star).where(Star.state == "floated", Star.floated_at >= start)
    return {"count": db.scalar(floated_today),
            "mine": db.scalar(floated_today.where(Star.user_id == user.id))}
