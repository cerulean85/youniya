"""What the model costs, per account per month (KRW), from each answer's usageMetadata.

Prices: Standard paid tier, https://ai.google.dev/gemini-api/docs/pricing (read 20261107), USD per 1M
tokens: (input, cached input, output including thinking). Flash doubles from 2027-01-01."""

import logging
from contextlib import contextmanager
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from . import llm
from .allowance import this_month
from .models import AdminLog, AiCost, User
from .rules import AI_COST_ALERT_KRW

log = logging.getLogger(__name__)
KRW_PER_USD = 1500  # round; a little above the 2026 rates seen
PRICES = {
    "gemini-3.8-flash": ((0.75, 0.075, 3.75), (1.50, 0.15, 7.50)),  # (through 2026, from 2027)
    "gemini-3.5-flash-lite": ((0.30, 0.03, 2.50),) * 2,
    "gemini-3.1-flash-lite": ((0.25, 0.025, 1.50),) * 2,
    "gemini-3.1-pro-preview": ((2.00, 0.20, 12.00),) * 2,
}
STORAGE_USD_PER_MTOK_HOUR = {"gemini-3.8-flash": (0.50, 1.00)}  # explicit cache storage


def krw(model: str, usage: dict, on: date | None = None) -> float:
    rates = PRICES.get(model)
    if rates is None:
        return 0.0
    pin, pcached, pout = rates[0] if (on or date.today()) < date(2027, 1, 1) else rates[-1]
    cached = usage.get("cachedContentTokenCount", 0)
    fresh = usage.get("promptTokenCount", 0) - cached
    out = usage.get("candidatesTokenCount", 0) + usage.get("thoughtsTokenCount", 0)
    return (fresh * pin + cached * pcached + out * pout) / 1e6 * KRW_PER_USD


@contextmanager
def metered(db: Session, user: User):
    """Every model call inside is added to the account's month, even when the feature then fails
    (the model was paid for). Over AI_COST_ALERT_KRW the operator hears of it once a month."""
    entries: list = []
    token = llm.meter.set(entries)
    try:
        yield
    finally:
        llm.meter.reset(token)
        if entries:
            record(db, user.id, entries)


def record(db: Session, user_id: str, entries: list) -> None:
    month = this_month()
    row = db.get(AiCost, (user_id, month)) or AiCost(user_id=user_id, month=month, krw=0.0, calls=0, alerted=False)
    row.krw += sum(krw(m, u) for m, u in entries)
    row.calls += len(entries)
    db.add(row)
    if row.krw > AI_COST_ALERT_KRW and not row.alerted:
        row.alerted = True
        db.add(AdminLog(action="ai_cost_over", target_id=user_id))
        log.error("AI cost for %s passed %s KRW in %s: %.0f KRW over %s calls",
                  user_id, AI_COST_ALERT_KRW, month, row.krw, row.calls)  # error: Sentry hears of it
    db.commit()


def month_costs(db: Session, month: str | None = None) -> list[AiCost]:
    return db.scalars(select(AiCost).where(AiCost.month == (month or this_month()))
                      .order_by(AiCost.krw.desc())).all()
