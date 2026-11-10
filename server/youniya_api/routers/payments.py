"""28 코인 충전 on the web: 토스페이먼츠 결제창 (v2 SDK `payment().requestPayment`), API 개별 연동.

1. GET  /v1/payments/toss/packages    what the web shows (the same packages as the App Store)
2. POST /v1/payments/toss/orders      the server sets the amount; the order waits 30 minutes
3. 결제창 → successUrl ?paymentKey&orderId&amount → the web's server calls
   POST /v1/payments/toss/confirm     checked against the order, approved with Toss, coins added once
4. POST /v1/payments/toss/webhook     PAYMENT_STATUS_CHANGED (set in the Toss developer center)
5. POST /v1/payments/toss/{id}/cancel 46 결제·환불 정책: within 7 days, while none of the coins are spent
"""

import hashlib
import hmac
import logging
import uuid
from datetime import datetime, timedelta, timezone

import httpx
from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import coins
from ..deps import ApiError, consented_user, get_db
from ..models import CoinEntry, TossOrder, User
from ..ratelimit import per_user
from ..rules import COIN_PACKAGES, REFUND_WINDOW_DAYS
from ..toss import TossClient, TossError
from ..views import aware, iso

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1/payments/toss", tags=["payments"])

ORDER_TTL = timedelta(minutes=30)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _toss(request: Request) -> TossClient:
    client = request.app.state.toss
    if client is None:
        raise ApiError(503, "payments_unavailable", "지금은 웹에서 코인을 충전할 수 없어요.")
    return client


def can_pay(request: Request, db: Session, user: User) -> bool:
    """With a test key (test_sk_…) a test card buys real coins for no money, so until the live key only
    accounts that existed before TOSS_TEST_ACCOUNTS_BEFORE may pay, and those named in TOSS_TEST_USER_IDS;
    any other account made after it may not (decided 2026-11-10). Unset: nobody. TOSS_TEST_OPEN=1
    (development) lets everyone."""
    s = request.app.state.settings
    if request.app.state.toss is None:
        return False
    if not s.toss_secret_key.startswith("test_") or s.toss_test_open:
        return True
    if user.id in s.toss_test_user_ids:
        return True
    return s.toss_test_accounts_before is not None and aware(user.created_at) < s.toss_test_accounts_before


def _entry_id(order: TossOrder) -> str:
    return f"toss:{order.id}"


def customer_key(request: Request, user: User) -> str:
    """Toss customerKey: stable per keeper, but not the user id itself."""
    digest = hmac.new(request.app.state.settings.jwt_secret.encode(), f"toss:{user.id}".encode(), hashlib.sha256)
    return f"yk_{digest.hexdigest()[:40]}"


@router.get("/packages")
def packages(request: Request, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    """`available` false: no web payments for this keeper now (no key, or a test key and not a tester)."""
    s = request.app.state.settings
    return {"items": [{"id": k, "coins": v["coins"], "bonus": v.get("bonus", 0), "price": v["price"]}
                      for k, v in COIN_PACKAGES.items() if v["sold"]],
            "client_key": s.toss_client_key,
            "available": can_pay(request, db, user)}


class OrderIn(BaseModel):
    package_id: str = Field(..., max_length=32)


@router.post("/orders", status_code=201, dependencies=[per_user("toss_order", 30, 3600)])
def create_order(body: OrderIn, request: Request, user: User = Depends(consented_user),
                 db: Session = Depends(get_db)):
    _toss(request)
    if not can_pay(request, db, user):
        raise ApiError(403, "payments_not_open", "지금은 웹 충전을 준비 중이에요. 앱에서 충전해 주세요.")
    package = COIN_PACKAGES.get(body.package_id)
    if package is None or not package["sold"]:
        raise ApiError(422, "unknown_product", "알 수 없는 상품이에요.")
    order = TossOrder(id=f"yn{uuid.uuid4().hex}", user_id=user.id, package_id=body.package_id,
                      coins=package["coins"], amount=package["price"], order_name=f"코인 {package['coins']}개",
                      status="pending", expires_at=_now() + ORDER_TTL)
    db.add(order)
    db.commit()
    return {"order_id": order.id, "amount": order.amount, "order_name": order.order_name,
            "customer_key": customer_key(request, user), "expires_at": iso(order.expires_at)}


class ConfirmIn(BaseModel):
    payment_key: str = Field(..., min_length=1, max_length=200)
    order_id: str = Field(..., min_length=1, max_length=64)
    amount: int


def _done(user: User, order: TossOrder, granted: int, again: bool) -> dict:
    return {"coins": user.coins, "granted": granted, "order_id": order.id, "already_processed": again}


def _grant(db: Session, order: TossOrder, payment: dict) -> int:
    """Marks the order paid and adds its coins, once. A deleted account's order is kept, with no coins."""
    order.status, order.payment_key = "done", payment.get("paymentKey") or order.payment_key
    order.method, order.approved_at, order.failure_code = payment.get("method"), _now(), None
    user = db.get(User, order.user_id) if order.user_id else None
    if user is None or db.scalar(select(CoinEntry.id).where(CoinEntry.transaction_id == _entry_id(order))):
        return 0
    coins.add(db, user, order.coins, "코인 충전", transaction_id=_entry_id(order))
    return order.coins


def _paid(payment: dict, order: TossOrder) -> bool:
    return (payment.get("status") == "DONE" and payment.get("orderId") == order.id
            and int(payment.get("totalAmount", -1)) == order.amount)


@router.post("/confirm", dependencies=[per_user("toss_confirm", 30, 3600)])
def confirm(body: ConfirmIn, request: Request, user: User = Depends(consented_user), db: Session = Depends(get_db)):
    toss = _toss(request)
    order = db.get(TossOrder, body.order_id)
    if order is None or order.user_id != user.id:
        raise ApiError(404, "order_not_found", "주문을 찾지 못했어요. 결제는 되지 않았어요.")
    if order.status == "done":  # the same order again: the coins were added the first time
        if order.payment_key != body.payment_key:
            raise ApiError(409, "order_used", "이미 결제가 끝난 주문이에요.")
        return _done(user, order, 0, True)
    if body.amount != order.amount:
        raise ApiError(409, "amount_mismatch", "결제 금액이 주문과 달라요. 결제는 되지 않았어요.")
    if order.status == "canceled":
        raise ApiError(409, "order_canceled", "취소된 주문이에요.")
    if order.status == "expired" or (order.status == "pending" and aware(order.expires_at) < _now()):
        order.status = "expired"
        db.commit()
        raise ApiError(404, "order_expired", "주문 시간이 지났어요. 결제는 되지 않았어요. 다시 시도해 주세요.")
    # Only one request approves an order; a second one racing it waits for the first to finish.
    if db.scalar(select(TossOrder.id).where(TossOrder.payment_key == body.payment_key, TossOrder.id != order.id)):
        raise ApiError(409, "payment_key_used", "다른 주문에 쓰인 결제예요.")
    try:
        claimed = db.execute(update(TossOrder).where(TossOrder.id == order.id, TossOrder.status == "pending")
                             .values(status="confirming", payment_key=body.payment_key)).rowcount
        db.commit()
    except IntegrityError:  # the same paymentKey racing on another order
        db.rollback()
        raise ApiError(409, "payment_key_used", "다른 주문에 쓰인 결제예요.")
    if not claimed:
        db.refresh(order)
        if order.status == "done" and order.payment_key == body.payment_key:
            db.refresh(user)
            return _done(user, order, 0, True)
        raise ApiError(409, "order_in_progress", "결제를 확인하고 있어요. 잠시 뒤 다시 확인해 주세요.")

    try:
        payment = toss.confirm(body.payment_key, order.id, order.amount)
    except TossError as e:
        payment = None
        if e.code == "ALREADY_PROCESSED_PAYMENT":  # approved before, but we never heard back
            try:
                payment = toss.payment(body.payment_key)
            except (TossError, httpx.HTTPError):
                payment = None
        if payment is None or not _paid(payment, order):
            # Refused: the order may be paid again with a new payment, so it lets go of this one.
            order.status, order.failure_code, order.payment_key = "pending", e.code[:64], None
            db.commit()
            raise ApiError(402, "payment_failed", e.message, toss_code=e.code)
    except httpx.HTTPError:
        # Unknown whether Toss approved it. Leave the order to be confirmed again (Toss answers
        # ALREADY_PROCESSED_PAYMENT then) or by the webhook.
        logger.exception("toss confirm for %s got no answer", order.id)
        order.status = "pending"
        db.commit()
        raise ApiError(502, "payment_unconfirmed", "결제 결과를 아직 받지 못했어요. 잠시 뒤 다시 확인해 주세요.")

    if not _paid(payment, order):
        logger.error("toss confirm for %s returned %s", order.id, payment.get("status"))
        order.status, order.failure_code, order.payment_key = "pending", f"status_{payment.get('status')}"[:64], None
        db.commit()
        raise ApiError(402, "payment_failed", "결제가 끝나지 않았어요. 코인은 지급되지 않았어요.",
                       toss_code=payment.get("status"))
    granted = _grant(db, order, payment)
    db.commit()
    db.refresh(user)
    return _done(user, order, granted, False)


class CancelIn(BaseModel):
    reason: str = Field("고객 요청", min_length=1, max_length=200)


def refund_block(order: TossOrder, balance: int) -> str | None:
    """Why this order can't be refunded under 46 결제·환불 정책, or None when it can."""
    if order.status != "done":
        return "not_done"
    if _now() - aware(order.approved_at) > timedelta(days=REFUND_WINDOW_DAYS):
        return "window_passed"
    if balance < order.coins:
        return "coins_spent"
    return None


def refund(db: Session, toss: TossClient, order: TossOrder, reason: str, title: str = "환불",
           force: bool = False) -> int:
    """Cancels the whole payment with Toss and takes its coins back; the caller commits. Returns the coins taken.
    By the policy: within 7 days, while all of the order's coins are unspent (409 otherwise). `force`
    (operators, for an outage and the like) cancels anyway and takes what is left, up to the order's coins,
    the balance stopping at 0. Nothing is kept if Toss refuses or doesn't answer."""
    if order.status != "done":
        raise ApiError(409, "order_not_paid", "결제가 끝나지 않은 주문이에요.")
    user = db.get(User, order.user_id) if order.user_id else None
    if not force:
        block = refund_block(order, user.coins if user else 0)
        if block == "window_passed":
            raise ApiError(409, "refund_window_passed", f"결제한 지 {REFUND_WINDOW_DAYS}일이 지나 환불할 수 없어요.")
    refund_id = f"refund:{_entry_id(order)}"
    taken = 0
    if user is not None and force:
        taken = coins.take_back(db, user, order.coins, title, transaction_id=refund_id)
    elif user is not None:
        # Taken first (in this transaction): a spend racing this one can't use the coins while Toss cancels.
        if not db.execute(update(User).where(User.id == user.id, User.coins >= order.coins)
                          .values(coins=User.coins - order.coins)).rowcount:
            db.rollback()
            raise ApiError(409, "coins_spent", "이미 쓴 코인이 있어 환불할 수 없어요.")
        db.add(CoinEntry(user_id=user.id, title=title, delta=-order.coins, transaction_id=refund_id))
        taken = order.coins
    elif not force:
        raise ApiError(409, "coins_spent", "이미 쓴 코인이 있어 환불할 수 없어요.")
    try:
        toss.cancel(order.payment_key, reason, idempotency_key=f"cancel-{order.id}")
    except TossError as e:
        db.rollback()
        raise ApiError(402, "cancel_failed", e.message, toss_code=e.code)
    except httpx.HTTPError:
        db.rollback()
        logger.exception("toss cancel for %s got no answer", order.id)
        raise ApiError(502, "cancel_unconfirmed", "환불 결과를 받지 못했어요. 잠시 뒤 다시 시도해 주세요.")
    order.status, order.canceled_at = "canceled", _now()
    return taken


def commit_refund(db: Session, order: TossOrder) -> bool:
    """Commits a refund. False if the webhook for the same cancel got there first (it took the coins)."""
    try:
        db.commit()
        return True
    except IntegrityError:
        db.rollback()
        db.refresh(order)
        return False


@router.post("/{order_id}/cancel", dependencies=[per_user("toss_cancel", 10, 3600)])
def cancel(order_id: str, body: CancelIn, request: Request, user: User = Depends(consented_user),
           db: Session = Depends(get_db)):
    """46 결제·환불 정책: the whole payment, within 7 days, while all of its coins are still unspent."""
    toss = _toss(request)
    order = db.get(TossOrder, order_id)
    if order is None or order.user_id != user.id:
        raise ApiError(404, "order_not_found", "주문을 찾지 못했어요.")
    if order.status == "canceled":
        return {"coins": user.coins, "taken": 0, "order_id": order.id, "already_processed": True}
    taken = refund(db, toss, order, body.reason)
    first = commit_refund(db, order)
    db.refresh(user)
    return {"coins": user.coins, "taken": taken if first else 0, "order_id": order.id, "already_processed": not first}


class WebhookIn(BaseModel):
    eventType: str = Field(..., max_length=64)
    data: dict = {}


@router.post("/webhook")
def webhook(body: WebhookIn, request: Request, db: Session = Depends(get_db)):
    """토스 웹훅 PAYMENT_STATUS_CHANGED. The body isn't trusted: the payment is read back from Toss with the
    secret key. DONE adds the coins of an order whose confirm answer was lost; CANCELED (canceled from the
    Toss console) takes back what is left of them, the balance stopping at 0."""
    toss = request.app.state.toss
    if toss is None:
        raise ApiError(404, "not_found", "찾지 못했어요.")
    key = body.data.get("paymentKey") if isinstance(body.data, dict) else None
    if body.eventType != "PAYMENT_STATUS_CHANGED" or not isinstance(key, str) or len(key) > 200:
        return {"handled": False}
    try:
        payment = toss.payment(key)
    except TossError:
        return {"handled": False}  # not a payment of ours
    except httpx.HTTPError:
        raise ApiError(502, "toss_unreachable", "결제를 확인하지 못했어요.")  # Toss sends it again
    order = db.get(TossOrder, payment.get("orderId") or "")
    if order is None or (order.payment_key and order.payment_key != key):
        return {"handled": False}
    status = payment.get("status")
    if status == "DONE" and order.status in ("pending", "confirming", "expired") and _paid(payment, order):
        _grant(db, order, payment)
        db.commit()
        return {"handled": True}
    if status in ("CANCELED", "PARTIAL_CANCELED") and order.status == "done":
        refund_id = f"refund:{_entry_id(order)}"
        user = db.get(User, order.user_id) if order.user_id else None
        if user is not None and db.scalar(select(CoinEntry.id).where(CoinEntry.transaction_id == refund_id)) is None:
            canceled = sum(int(c.get("cancelAmount", 0)) for c in payment.get("cancels") or [])
            share = order.coins if canceled >= order.amount else order.coins * canceled // order.amount
            coins.take_back(db, user, share, "환불", transaction_id=refund_id)
        order.status, order.canceled_at = "canceled", _now()
        db.commit()
        return {"handled": True}
    return {"handled": False}
