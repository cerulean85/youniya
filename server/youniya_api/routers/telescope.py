"""24 마음 망원경 켜기, 25 스캔 중, 88 관측 연출, 10 리포트, 26/27 리포트 목록, 29 코인 부족."""

import calendar
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import allowance, coins, membership
from ..deps import ApiError, consented_user, get_cipher, get_db
from ..models import Star, TelescopeReport, User
from ..rules import TELESCOPE_COST
from ..security import Cipher
from ..telescope import StarText, build_report
from ..views import iso, local
from ..ratelimit import per_user

router = APIRouter(prefix="/v1/telescope", tags=["telescope"])

_NTH = ("첫째", "둘째", "셋째", "넷째", "다섯째")


class ReportIn(BaseModel):
    # One star from its card (07), or none for the last seven days (98).
    star_ids: list[str] | None = Field(None, min_length=1, max_length=30)


def week_label(dt: datetime) -> str:
    """26: "11월 첫째 주", "10월 마지막 주"."""
    t = local(dt)
    last = t.day + 7 > calendar.monthrange(t.year, t.month)[1]
    return f"{t.month}월 {'마지막' if last else _NTH[(t.day - 1) // 7]} 주"


def _free_left(db: Session, request: Request, user: User) -> int:
    member = membership.is_member(db, request.app.state.settings, user)
    return allowance.telescopes_left(user) + (membership.telescopes_left(user) if member else 0)


def _view(r: TelescopeReport, cipher: Cipher) -> dict:
    return {"id": r.id, "title": week_label(r.created_at), "created_at": iso(r.created_at), "saved": r.saved,
            "star_ids": r.star_ids, "report": cipher.dec_json(r.report_enc)}


@router.get("/offer")
def offer(request: Request, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """`free_left`: a member's monthly ones, this month's free one and the sign-up one, if still unused."""
    left = _free_left(db, request, user)
    return {"free": left > 0, "free_left": left, "cost": 0 if left else TELESCOPE_COST, "coins": user.coins,
            "enough": left > 0 or user.coins >= TELESCOPE_COST}


@router.post("/reports", status_code=201, dependencies=[per_user("telescope", 10, 3600)])
def create_report(body: ReportIn, request: Request, user: User = Depends(consented_user),
                  db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    stmt = select(Star).where(Star.user_id == user.id, Star.state == "floated")
    if body.star_ids:
        stmt = stmt.where(Star.id.in_(body.star_ids))
    else:
        stmt = stmt.where(Star.created_at >= datetime.now(timezone.utc) - timedelta(days=7))
    stars = db.scalars(stmt.order_by(Star.created_at)).all()
    if not stars or (body.star_ids and len(stars) != len(set(body.star_ids))):
        raise ApiError(422, "no_stars", "망원경으로 볼 별이 없어요. 떠 있는 별만 볼 수 있어요.")

    free = _free_left(db, request, user) > 0
    if not free and user.coins < TELESCOPE_COST:
        raise ApiError(402, "insufficient_coins", "코인이 조금 부족해요.", coins=user.coins, cost=TELESCOPE_COST)

    settings = request.app.state.settings
    texts = [StarText(id=s.id, title=cipher.dec(s.title_enc), body=cipher.dec(s.body_enc),
                      created_at=iso(s.created_at), analysis=cipher.dec_json(s.analysis_enc)) for s in stars]
    try:
        report = build_report(texts, settings.gemini_api_key, settings.telescope_model, settings.telescope_thinking)
    except Exception:
        raise ApiError(502, "analysis_failed", "별을 읽지 못했어요. 코인은 차감되지 않았어요.")

    # Charged only once the report exists (Protoss punch concept 4.4).
    # A member's monthly ones go first, then the free monthly one, then the sign-up one.
    member = membership.is_member(db, request.app.state.settings, user)
    used_free = free and ((member and membership.use_telescope(db, user)) or allowance.use_telescope(db, user))
    if not used_free and not coins.spend(db, user, TELESCOPE_COST, "마음 망원경"):
        db.rollback()
        raise ApiError(402, "insufficient_coins", "코인이 조금 부족해요.", coins=user.coins, cost=TELESCOPE_COST)
    row = TelescopeReport(user_id=user.id, star_ids=[s.id for s in stars], report_enc=cipher.enc_json(report))
    db.add(row)
    db.commit()
    return _view(row, cipher) | {"charged": 0 if used_free else TELESCOPE_COST, "coins": user.coins}


@router.get("/reports")
def list_reports(order: Literal["newest", "oldest"] = "newest", user: User = Depends(consented_user),
                 db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """26 리포트 목록, 27 정렬"""
    col = TelescopeReport.created_at
    rows = db.scalars(select(TelescopeReport).where(TelescopeReport.user_id == user.id)
                      .order_by(col.desc() if order == "newest" else col)).all()
    return {"items": [{"id": r.id, "title": week_label(r.created_at), "created_at": iso(r.created_at),
                       "star_count": len(r.star_ids), "saved": r.saved,
                       "star_name": cipher.dec_json(r.report_enc)["star_name"]} for r in rows]}


def _owned(db: Session, user: User, report_id: str) -> TelescopeReport:
    r = db.get(TelescopeReport, report_id)
    if r is None or r.user_id != user.id:
        raise ApiError(404, "not_found", "리포트를 찾지 못했어요.")
    return r


@router.get("/reports/{report_id}")
def get_report(report_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db),
               cipher: Cipher = Depends(get_cipher)):
    return _view(_owned(db, user, report_id), cipher)


@router.post("/reports/{report_id}/save")
def save_report(report_id: str, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """10 리포트 보관하기"""
    r = _owned(db, user, report_id)
    r.saved = True
    db.commit()
    return {"saved": True}
