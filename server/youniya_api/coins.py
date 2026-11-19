"""Coin balance changes. Every change writes a 33 코인 사용 내역 entry, and keeps the coin lots (CoinLot) in step:
users.coins is the total, the lots say where each coin came from and whether it can expire."""

import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from . import mailer
from .models import CoinEntry, CoinLot, TossOrder, User
from .push import Message, notify
from .views import KST, aware

log = logging.getLogger(__name__)

# App Store coins never expire until Expiring Consumables is granted (사용자 결정 2026-11-19 "1번으로"); then new,
# expiring products are sold and coins of these stay exempt for good.
NON_EXPIRING_APP_STORE = {"coin_110", "coin_330", "coin_1100", "coin_50", "coin_120", "coin_300"}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def source_of(transaction_id: str | None) -> str:
    """toss (웹 결제) · google_play · app_store, from the entry's transaction id; server without one."""
    if not transaction_id:
        return "server"
    key = transaction_id.removeprefix("refund:")
    return "toss" if key.startswith("toss:") else "google_play" if key.startswith("gp:") else "app_store"


def _draw(db: Session, user_id: str, amount: int, first_lot: str | None = None) -> list[list]:
    """Takes `amount` from the lots, `first_lot` first, then the oldest. The caller has already taken it from
    users.coins, so the lots hold enough. Compare-and-set per lot against racing draws. Returns [[lot_id, n], …]."""
    taken: list[list] = []
    need = amount
    for _ in range(20):
        if need <= 0:
            return taken
        lots = db.execute(select(CoinLot.id, CoinLot.remaining)
                          .where(CoinLot.user_id == user_id, CoinLot.remaining > 0)
                          .order_by(CoinLot.id != first_lot, CoinLot.created_at, CoinLot.id)).all()
        if not lots:
            break
        for lot_id, rem in lots:
            n = min(rem, need)
            if db.execute(update(CoinLot).where(CoinLot.id == lot_id, CoinLot.remaining == rem)
                          .values(remaining=rem - n)).rowcount:
                taken.append([lot_id, n])
                need -= n
                if need <= 0:
                    break
            else:
                break  # someone drew from it meanwhile: read again
    if need > 0:
        log.error("coin lots of %s hold %d fewer than the balance", user_id, need)
    return taken


def spend(db: Session, user: User, amount: int, title: str) -> list[list] | None:
    """Atomic: never lets the balance go below zero, even with requests racing. Oldest coins first.
    Returns the lots drawn ([[lot_id, n], …], for give_back) or None when the balance is short."""
    done = db.execute(
        update(User).where(User.id == user.id, User.coins >= amount)
        .values(coins=User.coins - amount, coins_active_at=_now(), coins_notice_days=None)
    ).rowcount
    if not done:
        return None
    lots = _draw(db, user.id, amount)
    db.add(CoinEntry(user_id=user.id, title=title, delta=-amount))
    db.refresh(user)
    return lots


def add(db: Session, user: User, amount: int, title: str, transaction_id: str | None = None,
        refund_consent_at=None, product_id: str | None = None) -> None:
    """A charge: a new lot. App Store coins of NON_EXPIRING_APP_STORE products never expire."""
    if amount < 0:
        raise ValueError("use take_back to remove coins")
    db.execute(update(User).where(User.id == user.id)
               .values(coins=User.coins + amount, coins_active_at=_now(), coins_notice_days=None))
    entry = CoinEntry(user_id=user.id, title=title, delta=amount, transaction_id=transaction_id,
                      refund_consent_at=refund_consent_at)
    db.add(entry)
    db.flush()
    source = source_of(transaction_id)
    db.add(CoinLot(user_id=user.id, entry_id=entry.id, source=source, amount=amount, remaining=amount,
                   expires=not (source == "app_store" and product_id in NON_EXPIRING_APP_STORE)))
    db.refresh(user)


def give_back(db: Session, user: User, lots: list[list] | None, amount: int, title: str) -> None:
    """A cancelled use (별빛 받기 그만두기): the coins go back to the lots they came from. Restarts the year."""
    db.execute(update(User).where(User.id == user.id)
               .values(coins=User.coins + amount, coins_active_at=_now(), coins_notice_days=None))
    back = 0
    for lot_id, n in lots or []:
        if db.execute(update(CoinLot).where(CoinLot.id == lot_id, CoinLot.user_id == user.id)
                      .values(remaining=CoinLot.remaining + n)).rowcount:
            back += n
    if back < amount:  # no record of the lots (a use before lots existed): an expiring lot of the server's
        db.add(CoinLot(user_id=user.id, source="server", expires=True, amount=amount - back, remaining=amount - back))
    db.add(CoinEntry(user_id=user.id, title=title, delta=amount))
    db.refresh(user)


def _purchase_lot(db: Session, transaction_id: str | None) -> str | None:
    if not transaction_id:
        return None
    purchase_id = db.scalar(select(CoinEntry.id).where(CoinEntry.transaction_id == transaction_id.removeprefix("refund:")))
    return db.scalar(select(CoinLot.id).where(CoinLot.entry_id == purchase_id)) if purchase_id else None


def take(db: Session, user: User, amount: int, title: str, transaction_id: str | None = None) -> bool:
    """All of `amount` or nothing (False when the balance is short): 운영자 회수, a 7-day web refund.
    With a refund's transaction id the refunded purchase's lot goes first, then the oldest."""
    if not db.execute(update(User).where(User.id == user.id, User.coins >= amount)
                      .values(coins=User.coins - amount)).rowcount:
        return False
    _draw(db, user.id, amount, first_lot=_purchase_lot(db, transaction_id))
    db.add(CoinEntry(user_id=user.id, title=title, delta=-amount, transaction_id=transaction_id))
    db.refresh(user)
    return True


def take_back(db: Session, user: User, amount: int, title: str, transaction_id: str) -> int:
    """Refund policy (기획서 11.6, Figma 46): take back up to `amount`, but only what is left.
    The balance stops at 0. Returns how many coins were taken; the entry records exactly that.
    The refunded purchase's own lot goes first."""
    first = _purchase_lot(db, transaction_id)
    for _ in range(5):  # compare-and-set, so a spend racing with us can't push the balance below 0
        current = db.scalar(select(User.coins).where(User.id == user.id))
        taken = min(amount, max(current, 0))
        done = db.execute(update(User).where(User.id == user.id, User.coins == current)
                          .values(coins=current - taken)).rowcount
        if done:
            _draw(db, user.id, taken, first_lot=first)
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




# 코인 소멸 (runs/toss_contract_reply.md O절, 2026-12-01 시행): coins, bonus included, go when the account has neither
# charged nor used coins for a year. Charging (store, 토스, 운영자 지급) and spending restart the year, and so does a
# cancelled use; a refund does not. App Store coins of NON_EXPIRING_APP_STORE products never go. All expiring lots
# share one date, and coins are spent oldest first (Apple Expiring Consumables). Activity before the policy starts
# counts from its first day.
POLICY_START = datetime(2026, 12, 1, tzinfo=KST)
NOTICE_DAYS = (30, 7)  # 만료 30일·7일 전 (Apple Expiring Consumables)
EXPIRED_TITLE = "기간 만료 소멸"


def _plus_year(d: date) -> date:
    try:
        return d.replace(year=d.year + 1)
    except ValueError:  # 2월 29일
        return d.replace(year=d.year + 1, day=28)


def expiring(db: Session, user: User) -> int:
    """How many of the coins can expire."""
    return db.scalar(select(func.coalesce(func.sum(CoinLot.remaining), 0))
                     .where(CoinLot.user_id == user.id, CoinLot.expires.is_(True))) or 0


def last_day(user: User) -> date:
    """The last Korean day expiring coins can still be used; they go the day after."""
    since = max(aware(user.coins_active_at) if user.coins_active_at else POLICY_START, POLICY_START)
    return _plus_year(since.astimezone(KST).date())


def expiry_view(db: Session, user: User) -> dict:
    """For GET /v1/coins and the admin console: the expiring coins and their last day (null without any)."""
    n = expiring(db, user)
    return {"coins_expiring": n, "coins_expire_after": last_day(user).isoformat() if n else None}


def _notice_text(n: int, day: date) -> tuple[str, str]:
    when = f"{day.year}년 {day.month}월 {day.day}일"
    return ("코인 소멸 예정 안내",
            f"코인 {n}개는 {when}까지 충전하거나 쓰지 않으면 소멸돼요. "
            "코인을 충전하거나 쓰면 그날부터 다시 1년 동안 쓸 수 있어요.")


def expire_due(db: Session, push, cipher, settings, now: datetime | None = None, send_mail=mailer.send) -> dict:
    """Daily: the 30- and 7-day notices (알림함, push, and email when the sign-in gave one), then the expiring coins
    whose year is over go, with a 기간 만료 소멸 entry. Returns {"notified": n, "expired": n}."""
    now = now or _now()
    today = now.astimezone(KST).date()
    cutoff = now - timedelta(days=365 - NOTICE_DAYS[0] - 2)  # nothing newer is within 30 days of its end
    if POLICY_START >= cutoff:
        return {"notified": 0, "expired": 0}
    holders = select(CoinLot.user_id).where(CoinLot.expires.is_(True), CoinLot.remaining > 0)
    candidates = select(User).where(User.id.in_(holders), (User.coins_active_at.is_(None)) | (User.coins_active_at < cutoff))
    notified = expired = 0
    for user in db.scalars(candidates).all():
        n = expiring(db, user)
        if not n:
            continue
        day = last_day(user)
        left = (day - today).days
        active = user.coins_active_at
        # Only if nothing was charged or used since we looked: a racing spend keeps its coins.
        same = User.coins_active_at.is_(None) if active is None else User.coins_active_at == active
        if left < 0:
            # The account row locked first (Postgres), then counted again: a refund or spend can't slip in between.
            locked = db.execute(select(User.id).where(User.id == user.id, same).with_for_update()).first()
            n = expiring(db, user) if locked else 0
            if n and db.execute(update(User).where(User.id == user.id, User.coins >= n)
                                .values(coins=User.coins - n, coins_notice_days=None)).rowcount:
                db.execute(update(CoinLot).where(CoinLot.user_id == user.id, CoinLot.expires.is_(True))
                           .values(remaining=0))
                db.add(CoinEntry(user_id=user.id, title=EXPIRED_TITLE, delta=-n))
                expired += 1
            db.commit()
            continue
        due = min((d for d in NOTICE_DAYS if left <= d), default=None)
        if due is None or (user.coins_notice_days is not None and user.coins_notice_days <= due):
            continue
        old = user.coins_notice_days
        claimed = db.execute(update(User).where(User.id == user.id, same, User.coins_notice_days.is_(None)
                                                if old is None else User.coins_notice_days == old)
                             .values(coins_notice_days=due)).rowcount
        db.commit()  # claimed first: an overlapping run or a failing mail doesn't send it twice
        if not claimed:
            continue
        title, body = _notice_text(n, day)
        notify(db, push, [user.id], Message(title, body, "notice", {"screen": "coin_history"}))
        if user.email_enc and settings.resend_api_key:
            try:
                send_mail(settings.resend_api_key, settings.mail_from, cipher.dec(user.email_enc), f"[YOUNIYA] {title}",
                          body + "\n\n코인 잔액과 소멸 예정일은 앱의 코인 화면에서 볼 수 있어요.")
            except mailer.MailError:
                log.warning("coin expiry mail failed")
        notified += 1
    return {"notified": notified, "expired": expired}
