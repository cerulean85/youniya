"""별지기 멤버십 (기획서 13장, v1.1). Off unless MEMBERSHIP=1: then nobody is a member.

A member floats and polishes without limit, has MEMBER_TELESCOPES_PER_MONTH telescope reports a
calendar month (used before the free monthly one), gets a 월간 마음 리포트 and every sky."""

from datetime import datetime, timezone

from sqlalchemy import or_, select, update
from sqlalchemy.orm import Session

from .allowance import this_month
from .models import Subscription, User
from .rules import FREE_SKIES, MEMBER_TELESCOPES_PER_MONTH, MEMBERSHIP_PRODUCTS

LIVE = ("active", "grace")


def _ms(value) -> datetime | None:
    return datetime.fromtimestamp(int(value) / 1000, timezone.utc) if value else None


def current(db: Session, user: User) -> Subscription | None:
    """The subscription that reaches furthest, live or not."""
    return db.scalars(select(Subscription).where(Subscription.user_id == user.id)
                      .order_by(Subscription.expires_at.desc())).first()


def is_member(db: Session, settings, user: User, at: datetime | None = None) -> bool:
    if not settings.membership:
        return False
    at = at or datetime.now(timezone.utc)
    return db.scalar(select(Subscription.id).where(
        Subscription.user_id == user.id, Subscription.status.in_(LIVE), Subscription.expires_at > at)) is not None


def telescopes_left(user: User) -> int:
    used = user.member_telescope_count if user.member_telescope_month == this_month() else 0
    return max(0, MEMBER_TELESCOPES_PER_MONTH - used)


def use_telescope(db: Session, user: User) -> bool:
    month = this_month()
    done = db.execute(update(User).where(
        User.id == user.id, or_(User.member_telescope_month.is_(None), User.member_telescope_month != month))
        .values(member_telescope_month=month, member_telescope_count=1)).rowcount or \
        db.execute(update(User).where(User.id == user.id, User.member_telescope_month == month,
                                      User.member_telescope_count < MEMBER_TELESCOPES_PER_MONTH)
                   .values(member_telescope_count=User.member_telescope_count + 1)).rowcount
    db.refresh(user)
    return bool(done)


def sky_allowed(sky: str, member: bool) -> bool:
    return member or sky in FREE_SKIES


def view(db: Session, settings, user: User) -> dict:
    sub = current(db, user)
    member = is_member(db, settings, user)
    return {"active": member, "product_id": sub.product_id if sub else None,
            "expires_at": sub.expires_at.isoformat() if sub else None,
            "auto_renew": sub.auto_renew if sub else False, "status": sub.status if sub else None,
            "telescope_left_this_month": telescopes_left(user) if member else 0}


def current_for(db: Session, tx: dict) -> Subscription | None:
    original = str(tx.get("originalTransactionId") or tx.get("transactionId"))
    return db.scalar(select(Subscription).where(Subscription.original_transaction_id == original))


class NotSubscription(ValueError):
    pass


def record(db: Session, user_id: str, tx: dict, status: str | None = None, auto_renew: bool | None = None,
           expires_at: datetime | None = None) -> Subscription:
    """Creates or updates the subscription a signed transaction belongs to."""
    if tx.get("productId") not in MEMBERSHIP_PRODUCTS or tx.get("type") != "Auto-Renewable Subscription":
        raise NotSubscription(tx.get("productId"))
    original = str(tx.get("originalTransactionId") or tx["transactionId"])
    row = db.scalar(select(Subscription).where(Subscription.original_transaction_id == original))
    if row is None:
        row = Subscription(user_id=user_id, original_transaction_id=original, auto_renew=True)
        db.add(row)
    row.product_id = tx["productId"]
    row.transaction_id = str(tx["transactionId"])
    row.environment = tx.get("environment") or "Production"
    row.expires_at = expires_at or _ms(tx.get("expiresDate")) or row.expires_at
    if tx.get("revocationDate"):
        row.status = "revoked"
    elif status:
        row.status = status
    else:
        row.status = "active" if row.expires_at and row.expires_at > datetime.now(timezone.utc) else "expired"
    if auto_renew is not None:
        row.auto_renew = auto_renew
    db.flush()
    return row


def on_notification(db: Session, kind: str, subtype: str | None, tx: dict, renewal: dict | None) -> bool:
    """App Store Server Notifications V2 for the membership. Returns whether it changed anything."""
    original = str(tx.get("originalTransactionId") or tx.get("transactionId"))
    row = db.scalar(select(Subscription).where(Subscription.original_transaction_id == original))
    user_id = row.user_id if row else (tx.get("appAccountToken") or "").lower() or None
    if user_id is None or db.get(User, user_id) is None:
        return False  # bought outside the app's flow, or the account is gone
    renew = None
    if renewal and "autoRenewStatus" in renewal:
        renew = bool(renewal["autoRenewStatus"])
    if kind in ("SUBSCRIBED", "DID_RENEW"):
        record(db, user_id, tx, status="active", auto_renew=True if renew is None else renew)
    elif kind == "DID_CHANGE_RENEWAL_STATUS":
        record(db, user_id, tx, auto_renew=(subtype == "AUTO_RENEW_ENABLED") if renew is None else renew)
    elif kind == "DID_FAIL_TO_RENEW" and subtype == "GRACE_PERIOD":
        record(db, user_id, tx, status="grace", expires_at=_ms((renewal or {}).get("gracePeriodExpiresDate")))
    elif kind in ("EXPIRED", "GRACE_PERIOD_EXPIRED"):
        record(db, user_id, tx, status="expired", auto_renew=False)
    elif kind in ("REFUND", "REVOKE"):
        record(db, user_id, tx, status="revoked", auto_renew=False)
    else:
        return False
    return True


def free_summary(db: Session, settings, user: User) -> dict:
    """What /v1/me shows. A member's floats and polishes are unlimited (shown as 1), and the
    telescope count adds the membership's monthly ones."""
    from . import allowance

    out = allowance.summary(user, settings.free_stars_per_day)
    if is_member(db, settings, user):
        out = {"free_star_today": 1, "free_telescope": out["free_telescope"] + telescopes_left(user),
               "free_story": 1}
    return out
