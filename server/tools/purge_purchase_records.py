"""Deletes deleted accounts' purchase records once they are 5 years old (개인정보 처리방침 3).
Run daily by youniya-purge.timer; a missed day is caught up by the next run.

    python tools/purge_purchase_records.py [--dry-run]

Reads the server's environment (deploy/purge-purchase-records.sh sources .env.production)."""

import argparse
import sys
from pathlib import Path

from sqlalchemy import func, select
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api import coins  # noqa: E402
from youniya_api.config import Settings  # noqa: E402
from youniya_api.db import make_engine  # noqa: E402
from youniya_api.models import CoinEntry  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="count what would go, delete nothing")
    a = ap.parse_args()
    db = sessionmaker(make_engine(Settings().database_url))()
    kept = db.scalar(select(func.count()).select_from(CoinEntry).where(CoinEntry.user_id.is_(None)))
    gone = coins.purge_detached(db)
    if a.dry_run:
        db.rollback()
        print(f"dry run: {gone} of {kept} detached purchase records are past 5 years")
    else:
        db.commit()
        print(f"{gone} detached purchase records past 5 years deleted, {kept - gone} kept")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
