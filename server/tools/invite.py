"""초대 계정 (App Review) by hand. Reads DATABASE_URL like the server.

    python tools/invite.py create LOGIN    → prints a new password once
    python tools/invite.py reset LOGIN     → prints a new password once
    python tools/invite.py delete LOGIN    → removes the account and everything in it
    python tools/invite.py list

Sign-in needs INVITE_LOGIN=1 on the server."""

import argparse
import sys
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api import invites  # noqa: E402
from youniya_api.config import Settings  # noqa: E402
from youniya_api.db import make_engine  # noqa: E402
from youniya_api.models import InviteAccount, User  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["create", "reset", "delete", "list"])
    ap.add_argument("login", nargs="?")
    a = ap.parse_args()
    db = sessionmaker(make_engine(Settings().database_url))()
    if a.action == "list":
        for row in db.scalars(select(InviteAccount).order_by(InviteAccount.created_at)):
            print(row.login, row.user_id, row.created_at.isoformat())
        return
    if not a.login:
        sys.exit("LOGIN is required")
    if a.action == "create":
        user, password = invites.create(db, a.login)
        print(f"login {a.login.strip().lower()} · user {user.id}\npassword {password}")
    elif a.action == "reset":
        print(f"password {invites.reset(db, a.login)}")
    else:
        row = db.get(InviteAccount, a.login.strip().lower())
        if row is None:
            sys.exit(f"{a.login} does not exist")
        db.delete(db.get(User, row.user_id))
        db.commit()
        print(f"deleted {a.login}")


if __name__ == "__main__":
    main()
