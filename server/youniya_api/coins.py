"""Coin balance changes. Every change writes a 33 코인 사용 내역 entry."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session

from .models import CoinEntry, TossOrder, User


def spend(db: Session, user: User, amount: int, title: str) -> bool:
    """Atomic: never lets the balance go below zero, even with requests racing."""
    done = db.execute(
        update(User).where(User.id == user.id, User.coins >= amount).values(coins=User.coins - amount)
    ).rowcount
    if not done:
        return False
    db.add(CoinEntry(user_id=user.id, title=title, delta=-amount))
    db.refresh(user)
    return True


def add(db: Session, user: User, amount: int, title: str, transaction_id: str | None = None,
        refund_consent_at=None) -> None:
    if amount < 0:
        raise ValueError("use take_back to remove coins")
    db.execute(update(User).where(User.id == user.id).values(coins=User.coins + amount))
    db.add(CoinEntry(user_id=user.id, title=title, delta=amount, transaction_id=transaction_id,
                     refund_consent_at=refund_consent_at))
    db.refresh(user)


def take_back(db: Session, user: User, amount: int, title: str, transaction_id: str) -> int:
    """Refund policy (기획서 11.6, Figma 46): take back up to `amount`, but only what is left.
    The balance stops at 0. Returns how many coins were taken; the entry records exactly that."""
    for _ in range(5):  # compare-and-set, so a spend racing with us can't push the balance below 0
        current = db.scalar(select(User.coins).where(User.id == user.id))
        taken = min(amount, max(current, 0))
        done = db.execute(update(User).where(User.id == user.id, User.coins == current)
                          .values(coins=current - taken)).rowcount
        if done:
            db.add(CoinEntry(user_id=user.id, title=title, delta=-taken, transaction_id=transaction_id))
            db.refresh(user)
            return taken
    raise RuntimeError("balance kept changing")


# Google Play keeps voided purchases 30 days; a daily check looks back this far, so a missed day or two is caught.
PLAY_VOIDED_LOOKBACK = timedelta(days=7)


def take_back_play_voided(db: Session, play, now: datetime | None = None) -> int:
    """Google Play refunds (Voided Purchases API), with the App Store's rule (기획서 11.6): only the coins that
    are left go, the balance stops at 0, and each order is taken back once (`refund:gp:…`).
    Returns how many purchases were taken back."""
    from .google_api import play_transaction_id

    since = (now or datetime.now(timezone.utc)) - PLAY_VOIDED_LOOKBACK
    done = 0
    for v in play.voided(int(since.timestamp() * 1000)):
        key = play_transaction_id(v.get("orderId"), v.get("purchaseToken", ""))
        purchase = db.scalar(select(CoinEntry).where(CoinEntry.transaction_id == key))
        if purchase is None or purchase.delta <= 0:
            continue  # not a coin purchase of ours
        refund_id = f"refund:{key}"
        if db.scalar(select(CoinEntry.id).where(CoinEntry.transaction_id == refund_id)) is not None:
            continue
        user = db.get(User, purchase.user_id) if purchase.user_id else None
        if user is None:
            continue  # a deleted account has no coins left to take back
        take_back(db, user, purchase.delta, "환불", transaction_id=refund_id)
        db.commit()
        done += 1
    return done


# 전자상거래법: payment records are kept 5 years. After an account is deleted only its store purchases and
# refunds stay (user_id NULL, 개인정보 처리방침 3); this is how long. 5 × 365 days plus a leap day or two.
DETACHED_KEEP = timedelta(days=5 * 365 + 2)


def purge_detached(db: Session, now: datetime | None = None) -> int:
    """Deletes the purchase records of deleted accounts once they are older than DETACHED_KEEP.
    Records of living accounts are their own history and stay. Returns how many rows went."""
    cutoff = (now or datetime.now(timezone.utc)) - DETACHED_KEEP
    db.execute(delete(TossOrder).where(TossOrder.user_id.is_(None), TossOrder.created_at < cutoff))
    return db.execute(delete(CoinEntry).where(CoinEntry.user_id.is_(None), CoinEntry.created_at < cutoff)).rowcount
