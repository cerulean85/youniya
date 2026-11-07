"""월간 마음 리포트: who gets one, and making it."""

from datetime import datetime, timedelta

from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from . import ai_cost
from .models import MonthlyReport, Star, User
from .rules import MONTHLY_REPORT_MIN_STARS
from .security import Cipher
from .telescope import StarText, build_monthly
from .views import KST, iso


def previous_month(now: datetime | None = None) -> str:
    first = (now or datetime.now(KST)).astimezone(KST).replace(day=1)
    return (first - timedelta(days=1)).strftime("%Y-%m")


def stars_of(db: Session, user: User, month: str) -> list[Star]:
    """Stars floated in that Korean calendar month."""
    year, mon = map(int, month.split("-"))
    start = datetime(year, mon, 1, tzinfo=KST)
    end = datetime(year + mon // 12, mon % 12 + 1, 1, tzinfo=KST)
    return db.scalars(select(Star).where(Star.user_id == user.id, Star.state == "floated",
                                         Star.created_at >= start, Star.created_at < end)
                      .order_by(Star.created_at)).all()


def existing(db: Session, user: User, month: str) -> MonthlyReport | None:
    return db.scalar(select(MonthlyReport).where(MonthlyReport.user_id == user.id, MonthlyReport.month == month))


class NotEnoughStars(Exception):
    pass


def make(db: Session, user: User, month: str, cipher: Cipher, settings, cache: str | None = None) -> MonthlyReport:
    """One report a month, never remade. Requests racing for the same month make one: on Postgres
    they queue on a lock and the later ones find the first one's report.
    Raises NotEnoughStars, or whatever the model call raised (try again another day)."""
    if db.get_bind().dialect.name == "postgresql":
        db.execute(text("SELECT pg_advisory_xact_lock(hashtext(:k))"), {"k": f"monthly:{user.id}:{month}"})
    row = existing(db, user, month)
    if row:
        return row
    stars = stars_of(db, user, month)
    if len(stars) < MONTHLY_REPORT_MIN_STARS:
        raise NotEnoughStars(len(stars))
    texts = [StarText(id=s.id, title=cipher.dec(s.title_enc), body=cipher.dec(s.body_enc),
                      created_at=iso(s.created_at), analysis=cipher.dec_json(s.analysis_enc)) for s in stars]
    with ai_cost.metered(db, user):
        report = build_monthly(month, texts, settings.gemini_api_key, settings.telescope_model,
                               settings.telescope_thinking, cache)
    row = MonthlyReport(user_id=user.id, month=month, report_enc=cipher.enc_json(report))
    db.add(row)
    try:
        db.commit()
    except IntegrityError:  # another request made it first (SQLite has no lock)
        db.rollback()
        return existing(db, user, month)
    return row


def view(row: MonthlyReport, cipher: Cipher) -> dict:
    return cipher.dec_json(row.report_enc) | {"id": row.id, "created_at": iso(row.created_at)}
