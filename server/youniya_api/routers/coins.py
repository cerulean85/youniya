"""28 코인 충전, 102 충전 완료, 38 결제 미완료, 33/108 코인 사용 내역."""

import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import coins
from ..deps import ApiError, consented_user, get_db
from ..models import CoinEntry, User
from ..rules import COIN_PACKAGES, REFUND_WINDOW_DAYS
from ..storekit import PurchaseInvalid
from ..views import aware, iso
from ..ratelimit import per_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1/coins", tags=["coins"])


class PurchaseIn(BaseModel):
    # StoreKit 2 `Transaction.jwsRepresentation`. Buy with `appAccountToken` = the user id.
    signed_transaction: str | None = Field(None, max_length=20000)
    # 28: the buyer agreed that spent coins aren't refunded and that this purchase's coin use
    # goes to the App Store when a refund is requested. Stored per purchase.
    consumption_consent: bool = False
    # Development only (TRUST_PURCHASES=1), without a store.
    product_id: str | None = None
    transaction_id: str | None = Field(None, max_length=128)


@router.get("")
def balance(user: User = Depends(consented_user)):
    return {
        "coins": user.coins,
        "free_telescope_available": not user.free_telescope_used,
        "packages": [{"product_id": k, **v} for k, v in COIN_PACKAGES.items()],
    }


@router.get("/history")
def history(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(CoinEntry).where(CoinEntry.user_id == user.id)
                      .order_by(CoinEntry.created_at.desc())).all()
    # A refund that found no coins left to take stays in the DB (it stops a second take-back)
    # but isn't shown: there is nothing to tell the user.
    return {"items": [{"id": r.id, "kind": _kind(r), "title": r.title, "delta": r.delta,
                       "created_at": iso(r.created_at)} for r in rows
                      if not (_kind(r) == "refund" and r.delta == 0)]}


def _kind(entry: CoinEntry) -> str:
    """purchase (충전) · spend (사용) · refund (App Store 환불로 거둔 코인)"""
    if entry.transaction_id and entry.transaction_id.startswith("refund:"):
        return "refund"
    return "purchase" if entry.transaction_id else "spend"


@router.post("/purchases", dependencies=[per_user("purchase", 30, 3600)])
def purchase(body: PurchaseIn, request: Request, user: User = Depends(consented_user),
             db: Session = Depends(get_db)):
    verifier = request.app.state.storekit
    if body.signed_transaction and verifier:
        try:
            tx = verifier.verify_transaction(body.signed_transaction)
        except PurchaseInvalid:
            raise ApiError(422, "purchase_invalid", "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")
        token = tx.get("appAccountToken")
        if token and token.lower() != user.id:
            raise ApiError(409, "transaction_used", "이미 처리된 결제예요.")
        product_id, transaction_id, quantity = tx["productId"], str(tx["transactionId"]), int(tx.get("quantity", 1))
    elif request.app.state.settings.trust_purchases and body.product_id and body.transaction_id:
        product_id, transaction_id, quantity = body.product_id, body.transaction_id, 1
    else:
        # 38 결제가 끝나지 않았어요: nothing is added until the store confirms it.
        raise ApiError(503, "purchase_unverified", "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")

    package = COIN_PACKAGES.get(product_id)
    if package is None:
        raise ApiError(422, "unknown_product", "알 수 없는 상품이에요.")
    # Retried requests for the same store transaction add coins once.
    seen = db.scalar(select(CoinEntry).where(CoinEntry.transaction_id == transaction_id))
    if seen:
        if seen.user_id != user.id:
            raise ApiError(409, "transaction_used", "이미 처리된 결제예요.")
        return {"coins": user.coins, "added": 0, "already_processed": True}
    added = package["coins"] * quantity
    coins.add(db, user, added, "코인 충전", transaction_id=transaction_id,
              refund_consent_at=datetime.now(timezone.utc) if body.consumption_consent else None)
    db.commit()
    return {"coins": user.coins, "added": added, "already_processed": False}


notifications = APIRouter(prefix="/v1/storekit", tags=["coins"])


class NotificationIn(BaseModel):
    signedPayload: str = Field(..., max_length=50000)


@notifications.post("/notifications")
def app_store_notification(body: NotificationIn, request: Request, db: Session = Depends(get_db)):
    """App Store Server Notifications V2 (set this URL in App Store Connect).
    - CONSUMPTION_REQUEST: a refund was requested; tell Apple how much of the purchase was used.
    - REFUND: take back the purchase's coins that are left; the balance never goes below 0."""
    verifier = request.app.state.storekit
    if verifier is None:
        raise ApiError(404, "not_found", "찾지 못했어요.")
    try:
        note = verifier.verify_signed(body.signedPayload)
        data = note.get("data") or {}
        if data.get("bundleId") != verifier.bundle_id:
            raise PurchaseInvalid("another app's notification")
        kind = note.get("notificationType")
        if kind not in ("REFUND", "CONSUMPTION_REQUEST"):
            return {"handled": False}  # 200 so Apple stops resending
        tx = verifier.verify_signed(data["signedTransactionInfo"])
    except (PurchaseInvalid, KeyError):
        raise ApiError(400, "invalid_notification", "알림을 확인하지 못했어요.")

    transaction_id = str(tx["transactionId"])
    purchase = db.scalar(select(CoinEntry).where(CoinEntry.transaction_id == transaction_id))
    if purchase is None:
        return {"handled": False}
    if kind == "CONSUMPTION_REQUEST":
        return _answer_consumption_request(request, db, purchase, transaction_id,
                                           data.get("environment") or tx.get("environment") or "Production")
    refund_id = f"refund:{transaction_id}"
    if db.scalar(select(CoinEntry.id).where(CoinEntry.transaction_id == refund_id)) is None:
        user = db.get(User, purchase.user_id)
        if user is not None:
            coins.take_back(db, user, purchase.delta, "환불", transaction_id=refund_id)
            db.commit()
    return {"handled": True}


def consumption_info(purchase: CoinEntry, balance: int, now: datetime) -> dict:
    """Policy (Figma 46): spent coins are not refunded; unspent coins within 7 days of purchase are.
    Spent = received − min(received, balance), the same measure the REFUND take-back uses."""
    received = purchase.delta
    spent = received - min(received, max(balance, 0))
    within_week = now - aware(purchase.created_at) <= timedelta(days=REFUND_WINDOW_DAYS)
    return {
        "customerConsented": True,
        "consumptionPercentage": round(spent * 100000 / received),  # milli-percent: 25% = 25000
        "deliveryStatus": "DELIVERED",
        "refundPreference": "GRANT_FULL" if spent == 0 and within_week else "DECLINE",
        "sampleContentProvided": False,
    }


def _answer_consumption_request(request: Request, db: Session, purchase: CoinEntry, transaction_id: str,
                                environment: str) -> dict:
    # Apple: without the customer's consent, don't respond at all.
    if purchase.refund_consent_at is None:
        return {"handled": False, "reason": "no_consent"}
    client = request.app.state.appstore
    if client is None:
        logger.warning("CONSUMPTION_REQUEST for %s left unanswered: App Store API key not configured",
                       transaction_id)
        return {"handled": False, "reason": "not_configured"}
    user = db.get(User, purchase.user_id)
    info = consumption_info(purchase, user.coins if user else 0, datetime.now(timezone.utc))
    try:
        client.send_consumption(transaction_id, environment, info)
    except Exception:
        logger.exception("sending consumption info for %s failed", transaction_id)
        # Not 200: Apple sends the notification again, inside the 12-hour window.
        raise ApiError(502, "consumption_not_sent", "사용 정보를 보내지 못했어요.")
    return {"handled": True, "sent": info}
