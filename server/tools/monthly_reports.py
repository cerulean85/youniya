"""월간 마음 리포트, every day: last month's report for each member with enough stars who has none yet.
Running daily covers the 1st and tries again the next day when the model failed.

    python tools/monthly_reports.py [--month YYYY-MM]

Reads the server's environment (deploy/monthly-reports.sh sources .env.production).
Does nothing unless MEMBERSHIP=1."""

import argparse
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api import membership, monthly  # noqa: E402
from youniya_api.ai_cache import CacheManager  # noqa: E402
from youniya_api.telescope import MONTHLY_PROMPT  # noqa: E402
from youniya_api.config import Settings  # noqa: E402
from youniya_api.db import make_engine  # noqa: E402
from youniya_api.models import Subscription, User  # noqa: E402
from youniya_api.security import Cipher  # noqa: E402


def main() -> int:
    print("월간 마음 리포트 was removed (기획서 13.5, 2026-11-09): nothing to do.")
    return 0


def _old_main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--month")
    a = ap.parse_args()
    settings = Settings()
    if not settings.membership:
        print("MEMBERSHIP is off: nothing to do")
        return 0
    month = a.month or monthly.previous_month()
    cipher = Cipher(settings.data_key)
    db = sessionmaker(make_engine(settings.database_url), expire_on_commit=False)()
    now = datetime.now(timezone.utc)
    user_ids = set(db.scalars(select(Subscription.user_id).where(Subscription.status.in_(membership.LIVE),
                                                                 Subscription.expires_at > now)))
    # One explicit cache of the fixed prompt for the whole run, deleted at the end. Too small to cache
    # on gemini-3.8-flash for now (441 of the 1,024 tokens needed): then every call goes in full.
    caches = CacheManager(sessionmaker(make_engine(settings.database_url)), settings.gemini_api_key)
    cache = None
    if settings.gemini_api_key and user_ids:
        try:
            cache = caches.batch("monthly", settings.telescope_model, MONTHLY_PROMPT + "\n\n")
        except Exception as e:  # noqa: BLE001
            logging.warning("monthly cache not made: %s", type(e).__name__)
    made = skipped = failed = 0
    for user_id in sorted(user_ids):
        user = db.get(User, user_id)
        if user is None or monthly.existing(db, user, month):
            continue
        try:
            monthly.make(db, user, month, cipher, settings, cache)
            made += 1
        except monthly.NotEnoughStars:
            skipped += 1
        except Exception as e:  # noqa: BLE001 — tomorrow's run tries again
            db.rollback()
            failed += 1
            logging.warning("monthly report for %s failed: %s", user_id, type(e).__name__)
    if cache:
        caches.drop("monthly")
    print(f"{month}: {made} made, {skipped} with too few stars, {failed} failed (tried again tomorrow)")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
