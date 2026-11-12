"""28 코인 충전, 102 충전 완료, 38 결제 미완료, 33/108 코인 사용 내역."""

import logging
from typing import Literal
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import coins
from ..deps import ApiError, consented_user, get_db
from ..models import CoinEntry, User
from .. import allowance, membership
from ..rules import MEMBERSHIP_PRODUCTS
from ..rules import COIN_PACKAGES, REFUND_WINDOW_DAYS, STAR_FLOAT_COST, TELESCOPE_COST
from ..google_api import PlayPurchaseInvalid, PlayUnavailable, play_transaction_id
from ..storekit import PurchaseInvalid
from ..views import aware, iso
from ..ratelimit import per_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1/coins", tags=["coins"])


class PurchaseIn(BaseModel):
    # "android": Google Play Billing. Buy with obfuscatedAccountId = the user id.
    platform: Literal["ios", "android"] = "ios"
    # StoreKit 2 `Transaction.jwsRepresentation`. Buy with `appAccountToken` = the user id.
    signed_transaction: str | None = Field(None, max_length=20000)
    # Android: Purchase.getPurchaseToken() and getOrderId(); product_id is required too.
    purchase_token: str | None = Field(None, min_length=1, max_length=4096)
    order_id: str | None = Field(None, max_length=100)
    # 28: the buyer agreed that spent coins aren't refunded and that this purchase's coin use
    # goes to the App Store when a refund is requested. Stored per purchase.
    consumption_consent: bool = False
    # Development only (TRUST_PURCHASES=1), without a store.
    product_id: str | None = None
    transaction_id: str | None = Field(None, max_length=128)


@router.get("")
def balance(request: Request, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """`packages` lists only what is on sale; older products are still accepted and refunded."""
    return {
        "coins": user.coins,
        "free_telescope_available": allowance.telescopes_left(user) > 0,
        **membership.free_summary(db, request.app.state.settings, user),
        "prices": {"star": STAR_FLOAT_COST, "telescope": TELESCOPE_COST},
        "packages": [{"product_id": k, "coins": v["coins"], "price": v["price"], "bonus": v.get("bonus", 0)}
                     for k, v in COIN_PACKAGES.items() if v["sold"]],
    }


@router.get("/history")
def history(user: User = Depends(consented_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(CoinEntry).where(CoinEntry.user_id == user.id)
                      .order_by(CoinEntry.created_at.desc())).all()
    # A refund that found no coins left to take stays in the DB (it stops a second take-back)
    # but isn't shown: there is nothing to tell the user.
    return {"items": [{"id": r.id, "kind": _kind(r), "title": r.title, "delta": r.delta, "source": source(r),
                       "created_at": iso(r.created_at)} for r in rows
                      if not (_kind(r) == "refund" and r.delta == 0)]}


def source(entry: CoinEntry) -> str:
    """Where a purchase or refund was paid: toss (웹 결제) · google_play · app_store. Everything else is the
    server's."""
    if not entry.transaction_id:
        return "server"
    key = entry.transaction_id.removeprefix("refund:")
    return "toss" if key.startswith("toss:") else "google_play" if key.startswith("gp:") else "app_store"


def _kind(entry: CoinEntry) -> str:
    """purchase (충전) · spend (사용) · refund (App Store 환불로 거둔 코인)"""
    if entry.transaction_id and entry.transaction_id.startswith("refund:"):
        return "refund"
    return "purchase" if entry.transaction_id else "spend"


@router.post("/purchases", dependencies=[per_user("purchase", 30, 3600)])
def purchase(body: PurchaseIn, request: Request, user: User = Depends(consented_user),
             db: Session = Depends(get_db)):
    if body.platform == "android":
        return _google_play(body, request, user, db)
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

    return _grant(db, user, product_id, transaction_id, quantity, body.consumption_consent)


def _grant(db: Session, user: User, product_id: str, transaction_id: str, quantity: int, consent: bool) -> dict:
    package = COIN_PACKAGES.get(product_id)
    if package is None:
        raise ApiError(422, "unknown_product", "알 수 없는 상품이에요.")
    # Retried requests for the same store transaction add coins once.
    seen = db.scalar(select(CoinEntry).where(CoinEntry.transaction_id == transaction_id))
    if seen:
        if seen.user_id != user.id:  # another account's, or a deleted account's (user_id NULL)
            raise ApiError(409, "transaction_used", "이미 처리된 결제예요.")
        return {"coins": user.coins, "added": 0, "already_processed": True}
    added = package["coins"] * quantity
    coins.add(db, user, added, "코인 충전", transaction_id=transaction_id,
              refund_consent_at=datetime.now(timezone.utc) if consent else None)
    db.commit()
    return {"coins": user.coins, "added": added, "already_processed": False}


def _google_play(body: PurchaseIn, request: Request, user: User, db: Session) -> dict:
    """Google Play Billing (기획서 24장). The server asks Google (purchases.products.get), grants once per
    order, then consumes the purchase. `consumed` false: the app consumes it itself (consumeAsync), after the
    coins are granted; a retry of the same purchase grants nothing more and tries to consume again."""
    if not body.product_id:
        raise ApiError(422, "unknown_product", "알 수 없는 상품이에요.")
    play, settings = request.app.state.play, request.app.state.settings
    if play is not None and body.purchase_token:
        try:
            p = play.product_purchase(body.product_id, body.purchase_token)
        except PlayPurchaseInvalid:
            raise ApiError(422, "purchase_invalid", "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")
        except PlayUnavailable:
            raise ApiError(503, "purchase_unverified", "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")
        state = p.get("purchaseState", 0)
        if state == 2:
            raise ApiError(409, "purchase_pending", "결제가 아직 끝나지 않았어요. 끝나면 코인이 들어와요.")
        if state != 0:
            raise ApiError(422, "purchase_invalid", "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")
        if p.get("purchaseType") == 0 and not settings.allow_sandbox_purchases:
            raise ApiError(422, "purchase_invalid", "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")
        account = p.get("obfuscatedExternalAccountId")
        if account and account.lower() != user.id:
            raise ApiError(409, "transaction_used", "이미 처리된 결제예요.")
        transaction_id = play_transaction_id(p.get("orderId"), body.purchase_token)
        out = _grant(db, user, body.product_id, transaction_id, int(p.get("quantity") or 1), body.consumption_consent)
        consumed = p.get("consumptionState") == 1
        if not consumed:
            try:
                play.consume(body.product_id, body.purchase_token)
                consumed = True
            except (PlayPurchaseInvalid, PlayUnavailable) as e:
                logger.warning("consuming Play purchase %s failed: %s", transaction_id, e)
        return {**out, "consumed": consumed}
    if settings.trust_purchases and body.order_id:
        # Development only: no Google. The app consumes the purchase itself.
        return {**_grant(db, user, body.product_id, f"gp:{body.order_id}", 1, body.consumption_consent),
                "consumed": False}
    # Google Play is not configured (no service account yet): nothing is added.
    raise ApiError(503, "purchase_unverified", "결제를 확인하지 못했어요. 코인은 지급되지 않았어요.")


notifications = APIRouter(prefix="/v1/storekit", tags=["coins"])


class NotificationIn(BaseModel):
    signedPayload: str = Field(..., max_length=50000)


@notifications.post("/notifications")
def app_store_notification(body: NotificationIn, request: Request, db: Session = Depends(get_db)):
    """App Store Server Notifications V2 (set this URL in App Store Connect).
    - CONSUMPTION_REQUEST: a refund was requested; tell Apple how much of the purchase was used.
    - REFUND: take back the purchase's coins that are left; the balance never goes below 0.
    - 별지기 멤버십: SUBSCRIBED, DID_RENEW, DID_CHANGE_RENEWAL_STATUS, DID_FAIL_TO_RENEW (grace period),
      EXPIRED, GRACE_PERIOD_EXPIRED, REFUND and REVOKE keep the subscription current."""
    verifier = request.app.state.storekit
    if verifier is None:
        raise ApiError(404, "not_found", "찾지 못했어요.")
    try:
        note = verifier.verify_signed(body.signedPayload)
        data = note.get("data") or {}
        if data.get("bundleId") != verifier.bundle_id:
            raise PurchaseInvalid("another app's notification")
        kind = note.get("notificationType")
        tx = verifier.verify_signed(data["signedTransactionInfo"]) if data.get("signedTransactionInfo") else {}
        renewal = verifier.verify_signed(data["signedRenewalInfo"]) if data.get("signedRenewalInfo") else None
    except (PurchaseInvalid, KeyError):
        raise ApiError(400, "invalid_notification", "알림을 확인하지 못했어요.")

    if tx.get("productId") in MEMBERSHIP_PRODUCTS:  # 별지기 멤버십
        changed = membership.on_notification(db, kind, note.get("subtype"), tx, renewal)
        db.commit()
        return {"handled": changed}
    if kind not in ("REFUND", "CONSUMPTION_REQUEST") or not tx:
        return {"handled": False}  # 200 so Apple stops resending

    transaction_id = str(tx["transactionId"])
    purchase = db.scalar(select(CoinEntry).where(CoinEntry.transaction_id == transaction_id))
    if purchase is None:
        return {"handled": False}
    if kind == "CONSUMPTION_REQUEST":
        return _answer_consumption_request(request, db, purchase, transaction_id,
                                           data.get("environment") or tx.get("environment") or "Production")
    refund_id = f"refund:{transaction_id}"
    if db.scalar(select(CoinEntry.id).where(CoinEntry.transaction_id == refund_id)) is None:
        user = db.get(User, purchase.user_id) if purchase.user_id else None
        if user is not None:  # a deleted account has no coins left to take back
            coins.take_back(db, user, purchase.delta, "환불", transaction_id=refund_id)
            db.commit()
    return {"handled": True}


def consumption_info(purchase: CoinEntry, balance: int, now: datetime) -> dict:
    """Policy (Figma 46): a refund may be asked within 7 days of purchase, and is granted only if
    taking back this purchase's coins leaves the balance at 0 or more.
    consumptionPercentage reports what was actually used: received − min(received, balance)."""
    received = purchase.delta
    spent = received - min(received, max(balance, 0))
    within_week = now - aware(purchase.created_at) <= timedelta(days=REFUND_WINDOW_DAYS)
    return {
        "customerConsented": True,
        "consumptionPercentage": round(spent * 100000 / received),  # milli-percent: 25% = 25000
        "deliveryStatus": "DELIVERED",
        "refundPreference": "GRANT_FULL" if within_week and balance >= received else "DECLINE",
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
    user = db.get(User, purchase.user_id) if purchase.user_id else None  # None: the account was deleted
    info = consumption_info(purchase, user.coins if user else 0, datetime.now(timezone.utc))
    try:
        client.send_consumption(transaction_id, environment, info)
    except Exception:
        logger.exception("sending consumption info for %s failed", transaction_id)
        # Not 200: Apple sends the notification again, inside the 12-hour window.
        raise ApiError(502, "consumption_not_sent", "사용 정보를 보내지 못했어요.")
    return {"handled": True, "sent": info}
