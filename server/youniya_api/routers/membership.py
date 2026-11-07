"""별지기 멤버십 (v1.1): status, purchase and the 월간 마음 리포트. 404 unless MEMBERSHIP=1."""

import re

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import membership, monthly
from ..deps import ApiError, consented_user, get_cipher, get_db
from ..models import MonthlyReport, User
from ..ratelimit import per_user
from ..rules import MEMBERSHIP_PRODUCTS, MONTHLY_REPORT_MIN_STARS
from ..security import Cipher
from ..storekit import PurchaseInvalid


def enabled(request: Request) -> None:
    if not request.app.state.settings.membership:
        raise ApiError(404, "not_found", "찾지 못했어요.")


router = APIRouter(prefix="/v1", tags=["membership"], dependencies=[Depends(enabled)])


class VerifyIn(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    signed_transaction: str = Field(..., alias="signedTransaction", max_length=20000,
                                    description="Transaction.jwsRepresentation of the subscription purchase")


class MonthlyIn(BaseModel):
    month: str | None = Field(None, pattern=r"^\d{4}-\d{2}$", description="YYYY-MM; default: last month")


@router.get("/membership")
def status(request: Request, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """{active, product_id, expires_at, auto_renew, status, stars_left_today, telescope_left_today, story_left_today}"""
    return membership.view(db, request.app.state.settings, user)


@router.post("/membership/verify", dependencies=[per_user("purchase", 30, 3600)])
def verify(body: VerifyIn, request: Request, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """After a StoreKit 2 subscription purchase (or restore). Buy with appAccountToken = user id."""
    verifier = request.app.state.storekit
    if verifier is None:
        raise ApiError(503, "purchase_unverified", "결제를 확인하지 못했어요.")
    try:
        tx = verifier.verify_signed(body.signed_transaction)
    except PurchaseInvalid:
        raise ApiError(422, "invalid_purchase", "결제 정보를 확인하지 못했어요.")
    if tx.get("bundleId") != verifier.bundle_id or tx.get("productId") not in MEMBERSHIP_PRODUCTS:
        raise ApiError(422, "invalid_purchase", "결제 정보를 확인하지 못했어요.")
    if tx.get("environment") == "Sandbox" and not verifier.allow_sandbox:
        raise ApiError(422, "invalid_purchase", "결제 정보를 확인하지 못했어요.")
    token = (tx.get("appAccountToken") or "").lower()
    if token and token != user.id:
        raise ApiError(409, "transaction_used", "다른 계정의 결제예요.")
    sub = membership.current_for(db, tx)
    if sub and sub.user_id != user.id:
        raise ApiError(409, "transaction_used", "다른 계정의 결제예요.")
    try:
        membership.record(db, user.id, tx)
    except membership.NotSubscription:
        raise ApiError(422, "invalid_purchase", "결제 정보를 확인하지 못했어요.")
    db.commit()
    return membership.view(db, request.app.state.settings, user)


@router.get("/reports/monthly")
def list_monthly(user: User = Depends(consented_user), db: Session = Depends(get_db),
                 cipher: Cipher = Depends(get_cipher)):
    """Newest first: month, title and when it was made (open one with GET …/{month})."""
    rows = db.scalars(select(MonthlyReport).where(MonthlyReport.user_id == user.id)
                      .order_by(MonthlyReport.month.desc())).all()
    return {"items": [{"month": r.month, "title": cipher.dec_json(r.report_enc)["title"],
                       "created_at": r.created_at.isoformat()} for r in rows]}


@router.get("/reports/monthly/{month}")
def get_monthly(month: str, user: User = Depends(consented_user), db: Session = Depends(get_db),
                cipher: Cipher = Depends(get_cipher)):
    row = monthly.existing(db, user, month) if re.fullmatch(r"\d{4}-\d{2}", month) else None
    if row is None:
        raise ApiError(404, "not_found", "리포트를 찾지 못했어요.")
    return monthly.view(row, cipher)


@router.post("/reports/monthly", status_code=201, dependencies=[per_user("monthly", 10, 3600)])
def make_monthly(body: MonthlyIn, request: Request, user: User = Depends(consented_user),
                 db: Session = Depends(get_db), cipher: Cipher = Depends(get_cipher)):
    """The button on 123: the same rule as the 1st of the month, for last month by default.
    An existing report is returned as it is."""
    settings = request.app.state.settings
    if not membership.is_member(db, settings, user):
        raise ApiError(403, "member_only", "별지기 멤버십에서 받을 수 있어요.")
    month = body.month or monthly.previous_month()
    try:
        row = monthly.make(db, user, month, cipher, settings)
    except monthly.NotEnoughStars as e:
        raise ApiError(422, "not_enough_stars", f"그달에 별이 {MONTHLY_REPORT_MIN_STARS}개 이상 떠야 만들 수 있어요.",
                       stars=e.args[0], needed=MONTHLY_REPORT_MIN_STARS)
    except Exception:
        raise ApiError(502, "analysis_failed", "리포트를 만들지 못했어요. 잠시 뒤에 다시 시도해 주세요.")
    return monthly.view(row, cipher)
