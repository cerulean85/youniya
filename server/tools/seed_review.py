"""App Review seed: an invite account with a lived-in sky, and a plaza with something in it.

    python tools/seed_review.py [--login appreview] [--reset]

Reads the database and keys from the environment like the server (source .env or .env.production
first). Everything goes through the API's own routes, so the data is what the app would make.
Stars are scored by the offline evaluator, never the model, so the seed costs nothing and gives
the same result every time.

- The review account: 15 floated stars (8 deep, 1 초신성), 2 kept stars, 2 nebulae, 1 telescope report.
- Plaza: a curator account shares 6 stars and 3 nebulae; a guest account leaves 별빛 한 줄 on them.
  Lines fade after 24 hours: run again with --reset shortly before review.

The review password is printed once. --reset removes these accounts (and only these) first."""

import argparse
import dataclasses
import sys
from datetime import datetime, timezone
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api import invites  # noqa: E402
from youniya_api.config import Settings  # noqa: E402
from youniya_api.main import create_app  # noqa: E402
from youniya_api.models import InviteAccount, User  # noqa: E402
from youniya_api.prism import PrismEngine  # noqa: E402
from youniya_api.security import issue_access_token  # noqa: E402

from seed_texts import LINES, PLAZA, PLAZA_NEBULAE, REVIEW_FLOATED, REVIEW_KEPT  # noqa: E402

SEED_SUBS = ("plaza-curator", "plaza-guest")  # provider "seed"


class SeedPrism(PrismEngine):
    """The offline evaluator, without the 1,000-character minimum (the seed writing is shorter)."""

    def evaluate(self, title, body, min_length=0):
        return super().evaluate(title, body, min_length=0)


def _seed_user(db, sub: str) -> User:
    user = User(provider="seed", provider_sub=sub, settings={}, consented_at=datetime.now(timezone.utc))
    db.add(user)
    db.flush()
    return user


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--login", default="appreview")
    ap.add_argument("--reset", action="store_true")
    a = ap.parse_args()
    login = a.login.strip().lower()

    # The seed floats many stars in one day: lift the one-free-a-day rule for it.
    settings = dataclasses.replace(Settings(), gemini_api_key=None, free_stars_per_day=10**6)
    app = create_app(settings)
    app.state.prism = SeedPrism(None, settings.prism_model, settings.prism_samples)
    client = TestClient(app)

    with app.state.sessions() as db:
        old = [db.get(User, r.user_id) for r in db.scalars(select(InviteAccount).where(InviteAccount.login == login))]
        old += db.scalars(select(User).where(User.provider == "seed", User.provider_sub.in_(SEED_SUBS))).all()
        if old and not a.reset:
            sys.exit(f"seed accounts already exist ({len(old)}); run with --reset to replace them")
        for u in old:
            db.delete(u)
        db.commit()
        reviewer, password = invites.create(db, login)
        curator, guest = (_seed_user(db, s) for s in SEED_SUBS)
        db.commit()
        ids = reviewer.id, curator.id, guest.id

    def auth(user_id):
        return {"Authorization": f"Bearer {issue_access_token(user_id, settings.jwt_secret)}"}

    rv, cu, gu = (auth(i) for i in ids)

    def call(method, path, headers, **kw):
        r = client.request(method, path, headers=headers, **kw)
        if r.status_code >= 400:
            sys.exit(f"{method} {path}: {r.status_code} {r.text}")
        return r.json() if r.content else None

    client.post("/v1/me/consent", json={"terms": True, "privacy": True, "sensitive": True}, headers=rv)

    # The review account's sky.
    floated = [call("POST", "/v1/stars", rv, json={"mood": m, "title": t, "body": b, "mode": "float"})["star"]
               for t, m, b in REVIEW_FLOATED]
    for t, m, b in REVIEW_KEPT:
        call("POST", "/v1/stars", rv, json={"mood": m, "title": t, "body": b, "mode": "keep"})
    call("POST", "/v1/nebulae", rv, json={"name": "나를 알아 간 성운", "silhouette": "whale",
                                          "star_ids": [s["id"] for s in floated[:4]]})
    call("POST", "/v1/nebulae", rv, json={"name": "흐린 날의 성운", "star_ids": [s["id"] for s in floated[4:7]],
                                          "edges": [[0, 1], [1, 2]]})
    call("POST", "/v1/telescope/reports", rv, json={"star_ids": [floated[0]["id"]]})  # the free first one

    # The plaza.
    plaza = [call("POST", "/v1/stars", cu, json={"mood": m, "title": t, "body": b, "mode": "float"})["star"]
             for t, m, b, _ in PLAZA]
    shared_stars = 0
    for star, (_, _, _, quote) in zip(plaza, PLAZA):
        if quote:
            call("PUT", f"/v1/stars/{star['id']}/share", cu, json={"quote": quote})
            shared_stars += 1
    nebula_shares = []
    for name, silhouette, idx, quote in PLAZA_NEBULAE:
        n = call("POST", "/v1/nebulae", cu, json={"name": name, "silhouette": silhouette,
                                                  "star_ids": [plaza[i]["id"] for i in idx]})
        nebula_shares.append(call("PUT", f"/v1/nebulae/{n['id']}/share", cu,
                                  json={"receive_lines": True, "quote": quote})["share_id"])
    for share_id, text in zip(nebula_shares, LINES):
        call("POST", f"/v1/plaza/nebulae/{share_id}/lines", gu, json={"text": text})

    growth = call("GET", "/v1/growth", rv)
    print(f"review account: login {login} · user {ids[0]}")
    print(f"  {len(floated)} floated ({growth['deep']} deep, {growth['supernova']} 초신성), {len(REVIEW_KEPT)} kept, "
          f"2 nebulae, 1 telescope report · growth stage {growth['stage']}")
    print(f"plaza: {shared_stars} stars, {len(nebula_shares)} nebulae, {len(LINES)} lines (fade in 24 h)")
    print(f"password {password}")


if __name__ == "__main__":
    main()
