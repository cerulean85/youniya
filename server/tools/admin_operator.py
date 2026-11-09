"""관리자 콘솔 운영자, by hand: the first owner, or a new invitation when the console is out of reach.

    python tools/admin_operator.py invite EMAIL [--role owner|moderator]   → prints the setup token once
    python tools/admin_operator.py list

Reads DATABASE_URL like the server (source .env or .env.production first). The token goes to the
operator by hand; it works for 3 days, once (POST /v1/admin/auth/setup, then /setup/confirm)."""

import argparse
import sys
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api import operators as ops  # noqa: E402
from youniya_api.config import Settings  # noqa: E402
from youniya_api.db import make_engine  # noqa: E402
from youniya_api.models import Operator  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["invite", "list"])
    ap.add_argument("email", nargs="?")
    ap.add_argument("--role", choices=ops.ROLES, default="owner")
    a = ap.parse_args()
    db = sessionmaker(make_engine(Settings().database_url))()
    if a.action == "list":
        for r in db.scalars(select(Operator).order_by(Operator.created_at)):
            print(r.email, r.role, r.status, r.created_at.isoformat())
        return
    if not a.email:
        sys.exit("EMAIL is required")
    try:
        row, token = ops.invite(db, a.email, a.role, None)
    except ValueError:
        sys.exit(f"{a.email} is already set up")
    ops.audit(db, None, "operator_invite", target=f"operator:{row.id}", reason="tools/admin_operator.py", role=a.role)
    db.commit()
    print(f"{row.email} ({row.role}) · setup token, valid 3 days, shown once:\n{token}")


if __name__ == "__main__":
    main()
