"""별지기 멤버십 (v1.1): status and purchase. 404 unless MEMBERSHIP=1. (월간 마음 리포트: removed, 410.)"""


from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from .. import membership
from ..deps import ApiError, consented_user, get_db
from ..models import User
from ..ratelimit import per_user
from ..rules import MEMBERSHIP_PRODUCTS
from ..storekit import PurchaseInvalid


def enabled(request: Request) -> None:
    if not request.app.state.settings.membership:
        raise ApiError(404, "not_found", "찾지 못했어요.")


router = APIRouter(prefix="/v1", tags=["membership"], dependencies=[Depends(enabled)])


class VerifyIn(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    signed_transaction: str = Field(..., alias="signedTransaction", max_length=20000,
                                    description="Transaction.jwsRepresentation of the subscription purchase")


@router.get("/membership")
def status(request: Request, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """{active, product_id, expires_at, auto_renew, status, stars_left_today, telescope_left_today}"""
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


@router.api_route("/reports/monthly", methods=["GET", "POST"], include_in_schema=False)
@router.api_route("/reports/monthly/{month}", methods=["GET"], include_in_schema=False)
def monthly_removed(month: str | None = None):
    """월간 마음 리포트 was removed (기획서 13.5, 2026-11-09): 410, nothing made. Reports already made stay in
    93 내보내기 and go with the account."""
    raise ApiError(410, "feature_removed", "월간 마음 리포트는 이제 없어요.")
