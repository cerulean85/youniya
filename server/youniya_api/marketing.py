"""새 기능·혜택 알림 수신 동의 (14.3, 정보통신망법 50조). A separate, optional consent: when it was
given and withdrawn is kept, the result is told to the user by an app notice, and every two years
the user is reminded that it is on. Advertising pushes: "(광고)" first, at most four a month, never
from 21:00 to 08:00 KST. Star reminders and service notices are not advertising."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .models import AdminLog, User
from .push import Message, notify
from .views import KST, aware, iso, local

RECONFIRM_EVERY = timedelta(days=730)
ADS_PER_MONTH = 4


def _day(at: datetime) -> str:
    d = local(at)
    return f"{d.year}년 {d.month}월 {d.day}일"


def view(user: User) -> dict:
    due = None
    if user.marketing_opt_in:
        since = aware(user.marketing_reminded_at or user.marketing_consented_at or user.created_at)
        due = since + RECONFIRM_EVERY
    return {"opt_in": user.marketing_opt_in, "consented_at": iso(user.marketing_consented_at),
            "revoked_at": iso(user.marketing_revoked_at), "reconfirm_due": iso(due)}


def set_consent(db: Session, push, user: User, opt_in: bool) -> bool:
    """Records the change and tells the user (법 50조 7항). Returns whether anything changed."""
    if user.marketing_opt_in == opt_in:
        return False
    now = datetime.now(timezone.utc)
    user.marketing_opt_in = opt_in
    if opt_in:
        user.marketing_consented_at, user.marketing_reminded_at = now, None
    else:
        user.marketing_revoked_at = now
    day = _day(now)
    message = Message("새 기능·혜택 알림 " + ("수신에 동의하셨어요" if opt_in else "수신을 거부하셨어요"),
                      f"{day}에 처리됐어요. 설정 › 알림에서 언제든 바꿀 수 있어요.", "consent_result")
    db.flush()
    notify(db, push, [user.id], message)
    return True


def ads_this_month(db: Session) -> int:
    start = datetime.now(KST).replace(day=1, hour=0, minute=0, second=0, microsecond=0).astimezone(timezone.utc)
    return db.scalar(select(func.count()).select_from(AdminLog)
                     .where(AdminLog.action == "announce", AdminLog.created_at >= start)) or 0


def remind_due(db: Session, push, now: datetime | None = None) -> int:
    """Every two years of consent: a notice that it is still on (시행령 62조의3)."""
    now = now or datetime.now(timezone.utc)
    cutoff = now - RECONFIRM_EVERY
    users = db.scalars(select(User).where(User.marketing_opt_in.is_(True))).all()
    due = [u for u in users if aware(u.marketing_reminded_at or u.marketing_consented_at or u.created_at) <= cutoff]
    for u in due:
        since = _day(aware(u.marketing_consented_at or u.created_at))
        notify(db, push, [u.id], Message(
            "새 기능·혜택 알림 수신 동의 안내",
            f"{since}에 동의하신 수신 동의가 유지되고 있어요. 원치 않으면 설정 › 알림에서 끌 수 있어요.",
            "consent_result"))
        u.marketing_reminded_at = now
    db.commit()
    return len(due)
