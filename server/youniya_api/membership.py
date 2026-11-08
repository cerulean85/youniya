"""별지기 멤버십 (기획서 13장, v1.1). Off unless MEMBERSHIP=1: then nobody is a member.

A member has MEMBER_DAILY_LIMIT floats and telescope reports a Korean day each,
used before the free ones everybody has; after both, coins. Also a 월간 마음 리포트 and every sky."""

from datetime import datetime, timezone

from sqlalchemy import or_, select, update
from sqlalchemy.orm import Session

from . import allowance
from .models import Subscription, User
from .rules import FREE_SKIES, MEMBER_DAILY_LIMIT, MEMBERSHIP_PRODUCTS

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


COUNTS = {"star": "member_star_count", "telescope": "member_telescope_count"}


def left_today(user: User, feature: str) -> int:
    used = getattr(user, COUNTS[feature]) if user.member_day == allowance.today() else 0
    return max(0, MEMBER_DAILY_LIMIT - used)


def use_today(db: Session, user: User, feature: str) -> bool:
    """Claims one of today's member uses of a feature; a new day starts every count at 0."""
    day, column = allowance.today(), getattr(User, COUNTS[feature])
    db.execute(update(User).where(User.id == user.id, or_(User.member_day.is_(None), User.member_day != day))
               .values(member_day=day, member_star_count=0, member_telescope_count=0))
    done = db.execute(update(User).where(User.id == user.id, User.member_day == day, column < MEMBER_DAILY_LIMIT)
                      .values({column: column + 1})).rowcount
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
            "stars_left_today": left_today(user, "star") if member else 0,
            "telescope_left_today": left_today(user, "telescope") if member else 0}


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
    """What /v1/me shows: the free uses left, a member's for today added."""

    out = allowance.summary(user, settings.free_stars_per_day)
    if is_member(db, settings, user):
        out = {"free_star_today": out["free_star_today"] + left_today(user, "star"),
               "free_telescope": out["free_telescope"] + left_today(user, "telescope")}
    return out
