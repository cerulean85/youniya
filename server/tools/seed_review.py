"""App Review seed: an invite account with a lived-in sky, and a plaza with something in it.

    python tools/seed_review.py [--login appreview] [--reset]

Reads the database and keys from the environment like the server (source .env or .env.production
first). Everything goes through the API's own routes, so the data is what the app would make.
Stars are scored by the offline evaluator, never the model, so the seed costs nothing and gives
the same result every time.

- The review account (별지기 이름 새벽산책, joined 40 days ago): 15 stars, 10 with starlight and 5
  without, 7 of them last month and 8 this month, so both months' 별자리 have stars; 2 more without
  starlight (the old 간직한 별); 별 잇기 within and across the months, one 고쳐 쓰기; 1 telescope result;
  one star shared with its whole writing, with 별빛 한 줄 from the curator and the guest.
  For builds before 20261109 also 2 nebulae.
- Plaza: a curator (고요한밤) shares 6 stars with their whole writing and 3 nebulae; a guest
  (다정한바람) leaves 별빛 한 줄 on the stars (they stay) and on the nebulae (they fade after 24 hours:
  run again with --reset shortly before review if the older builds matter).

The review password is printed once. --reset removes these accounts (and only these) first."""

import argparse
import dataclasses
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api import invites  # noqa: E402
from youniya_api.config import Settings  # noqa: E402
from youniya_api.main import create_app  # noqa: E402
from youniya_api.models import InviteAccount, Star, User  # noqa: E402
from youniya_api.views import KST  # noqa: E402
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
    # No model (the offline evaluator scores), and nothing of the seed run goes to Sentry.
    settings = dataclasses.replace(Settings(), gemini_api_key=None, free_stars_per_day=10**6, sentry_dsn=None)
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

    for headers, name in ((rv, "새벽산책"), (cu, "고요한밤"), (gu, "다정한바람")):
        call("PUT", "/v1/me/nickname", headers, json={"name": name})

    # The review account's sky: 10 lit and 5 unlit, the first 7 moved to last month below.
    floated = [call("POST", "/v1/stars", rv, json={"mood": m, "title": t, "body": b,
                                                   "mode": "lit" if i < 10 else "unlit"})["star"]
               for i, (t, m, b) in enumerate(REVIEW_FLOATED)]
    for t, m, b in REVIEW_KEPT:
        call("POST", "/v1/stars", rv, json={"mood": m, "title": t, "body": b, "mode": "unlit"})
    with app.state.sessions() as db:
        now = datetime.now(timezone.utc)
        db.get(User, ids[0]).created_at = now - timedelta(days=40)
        last_month = (datetime.now(KST).replace(day=1) - timedelta(days=1)).replace(hour=21, minute=0)
        for i, star in enumerate(floated[:7]):
            row = db.get(Star, star["id"])
            row.created_at = (last_month - timedelta(days=2 * (6 - i))).astimezone(timezone.utc)
            if row.floated_at:
                row.floated_at = row.created_at
        db.commit()
    # 별 잇기: within last month, within this month, and across the two; then one 고쳐 쓰기.
    call("POST", f"/v1/stars/{floated[0]['id']}/links", rv, json={"star_ids": [floated[2]["id"], floated[4]["id"]]})
    call("POST", f"/v1/stars/{floated[8]['id']}/links", rv, json={"star_ids": [floated[11]["id"]]})
    call("POST", f"/v1/stars/{floated[5]['id']}/links", rv, json={"star_ids": [floated[9]["id"]]})
    t, m, b = REVIEW_FLOATED[9]
    call("POST", "/v1/stars", rv, json={"mood": m, "title": f"{t}, 다시", "mode": "unlit", "rewrite_of": floated[9]["id"],
                                        "body": b + " 다시 읽어 보니 그날의 마음이 조금 더 부드럽게 보인다."})
    call("POST", "/v1/nebulae", rv, json={"name": "나를 알아 간 성운", "silhouette": "whale",
                                          "star_ids": [s["id"] for s in floated[:4]]})
    call("POST", "/v1/nebulae", rv, json={"name": "흐린 날의 성운", "star_ids": [s["id"] for s in floated[4:7]],
                                          "edges": [[0, 1], [1, 2]]})
    call("POST", "/v1/telescope/reports", rv, json={"star_ids": [floated[8]["id"]]})  # the free first one
    mine = call("PUT", f"/v1/stars/{floated[8]['id']}/share", rv,
                json={"quote": REVIEW_FLOATED[8][2].split(". ")[0] + ".", "full_text": True})["share_id"]

    # The plaza.
    plaza = [call("POST", "/v1/stars", cu, json={"mood": m, "title": t, "body": b, "mode": "float"})["star"]
             for t, m, b, _ in PLAZA]
    shared_stars = 0
    for star, (_, _, _, quote) in zip(plaza, PLAZA):
        if quote:
            share = call("PUT", f"/v1/stars/{star['id']}/share", cu, json={"quote": quote, "full_text": True})
            call("POST", f"/v1/plaza/stars/{share['share_id']}/lines", gu, json={"chip": "me_too"})
            shared_stars += 1
    nebula_shares = []
    for name, silhouette, idx, quote in PLAZA_NEBULAE:
        n = call("POST", "/v1/nebulae", cu, json={"name": name, "silhouette": silhouette,
                                                  "star_ids": [plaza[i]["id"] for i in idx]})
        nebula_shares.append(call("PUT", f"/v1/nebulae/{n['id']}/share", cu,
                                  json={"receive_lines": True, "quote": quote})["share_id"])
    for share_id, text in zip(nebula_shares, LINES):
        call("POST", f"/v1/plaza/nebulae/{share_id}/lines", gu, json={"text": text})
    # 별빛 한 줄 the review account receives on its shared star (only it can read them).
    call("POST", f"/v1/plaza/stars/{mine}/lines", cu, json={"text": "그 마음을 꺼내 줘서 고마워요"})
    call("POST", f"/v1/plaza/stars/{mine}/lines", gu, json={"chip": "empathize"})

    months = call("GET", "/v1/constellations", rv)["items"]
    print(f"review account: login {login} · user {ids[0]} · 별지기 이름 새벽산책")
    print(f"  {len(floated) + len(REVIEW_KEPT) + 1} stars (10 lit) · "
          + ", ".join(f"{m['month']} {m['name']} {m['filled']}/{m['total']}" for m in months[:2])
          + " · 4 links, 1 telescope result, 1 shared star with 2 lines, 2 nebulae")
    print(f"plaza: {shared_stars} stars with lines, {len(nebula_shares)} nebulae, {len(LINES)} nebula lines (fade in 24 h)")
    print(f"password {password}")


if __name__ == "__main__":
    main()
