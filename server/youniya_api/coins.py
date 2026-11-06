"""Coin balance changes. Every change writes a 33 코인 사용 내역 entry."""

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from .models import CoinEntry, User


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


def use_free_telescope(db: Session, user: User) -> bool:
    done = db.execute(
        update(User).where(User.id == user.id, User.free_telescope_used.is_(False)).values(free_telescope_used=True)
    ).rowcount
    db.refresh(user)
    return bool(done)


def add(db: Session, user: User, amount: int, title: str, transaction_id: str | None = None) -> None:
    if amount < 0:
        raise ValueError("use take_back to remove coins")
    db.execute(update(User).where(User.id == user.id).values(coins=User.coins + amount))
    db.add(CoinEntry(user_id=user.id, title=title, delta=amount, transaction_id=transaction_id))
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
