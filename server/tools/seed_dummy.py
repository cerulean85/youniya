"""Dummy data for testing: per account, 10 stars (7 with starlight, 3 without), one nebula drawn from
4 lit stars and shared to the sky, and 2 stars shared to the plaza (one sentence only, one full text).

Starlight comes from the offline prism (mock_sample): no model call, no AI cost. Every inserted id is
written to a JSON file so the batch can be removed again (--remove <file>).

    (set -a; . ./.env; set +a; PYTHONPATH=. .venv/bin/python tools/seed_dummy.py --out <file> [--go])
    (set -a; . ./.env; set +a; PYTHONPATH=. .venv/bin/python tools/seed_dummy.py --remove <file>)

Without --go it only checks the key and lists the accounts."""

import argparse
import json
import os
import random
import sys
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, select
from sqlalchemy.orm import sessionmaker

from youniya_api import privacy
from youniya_api.db import make_engine
from youniya_api.models import Nebula, NebulaShare, Star, StarShare, User
from youniya_api.prism.engine import mock_sample, to_analysis
from youniya_api.rules import PRISM_VERSION
from youniya_api.security import Cipher

WRITINGS = [
    ("calm", "느린 아침", "오늘은 알람 없이 일어났다. 창밖이 고요해서 한참 누워 있었는데 마음이 편안했다. 서두르지 않아도 괜찮다는 걸 몸이 먼저 알고 있는 것 같았다."),
    ("sorrow", "보내지 못한 말", "할머니 댁 앞을 지나다가 눈물이 났다. 그립다는 말을 한 번도 제대로 못 한 게 아직도 서운하다. 그 마음이 어디에 머물러 있는지 오늘에서야 조금 알 것 같다."),
    ("anger", "회의가 끝나고", "회의에서 내 의견이 또 묻혔다. 화가 나서 퇴근길 내내 답답했다. 정리해 보면 나는 무시당했다는 느낌보다 내가 말하지 못한 게 더 억울했던 것 같다."),
    ("insight", "이제 보니", "친구가 잘됐다는 소식에 축하하면서도 속이 쓰렸다. 이제 보니 나는 내 기준을 남의 속도에 맞추고 있었다. 내가 원했던 건 이기는 게 아니라 안심하는 거였다."),
    ("calm", "산책", "저녁에 동네를 한 바퀴 걸었다. 바람이 차분해서 생각도 같이 가라앉았다. 오늘 하루가 괜찮았다고 말해 줘도 될 것 같은 기분이었다."),
    ("sorrow", "빈 자리", "이사 간 친구의 자리가 오늘따라 크게 느껴졌다. 외로운 마음이 들어서 사진을 오래 봤다. 슬프지만 그 시간이 있어서 다행이라는 마음도 함께 있었다."),
    ("insight", "작은 깨달음", "늘 바쁘다고 말하던 내가 사실은 쉬는 게 무서웠다는 걸 알게 됐다. 왜 그렇게 느꼈을까 생각해 보니 쉬면 뒤처질 것 같은 불안이 있었다."),
    ("anger", "줄 서다가", "마트에서 새치기를 당했는데 아무 말도 못 했다. 짜증이 나서 집에 와서도 계속 그 장면이 떠올랐다. 다음엔 내 자리를 지키는 말을 해 보고 싶다."),
    ("calm", "비 오는 날", "비 소리를 들으며 차를 마셨다. 오랜만에 휴대폰을 멀리 두고 책을 읽었다. 마음이 쉬어 가는 느낌이 들어서 이런 시간을 자주 만들고 싶어졌다."),
    ("insight", "다시 읽은 편지", "예전에 쓴 편지를 다시 읽었다. 그때의 나는 생각보다 용감했다. 정리해 보면 나는 지금도 그 마음을 갖고 있는데 잊고 살았던 것 같다."),
    ("sorrow", "끝난 드라마", "좋아하던 드라마가 끝났다. 괜히 서운하고 마음 한쪽이 비어 있는 것 같았다. 무언가를 떠나보내는 연습을 이렇게 작게 하고 있는지도 모르겠다."),
    ("calm", "정리한 책상", "미뤄 두던 책상을 정리했다. 깨끗해진 자리를 보니 마음도 같이 정돈되는 기분이었다. 오늘은 이 정도면 충분하다고 스스로에게 말해 줬다."),
    ("insight", "거절한 날", "처음으로 부탁을 거절했다. 미안한 마음이 오래 남았지만 이제 보니 나를 지키는 일이기도 했다. 내가 원하는 건 모두에게 좋은 사람이 되는 게 아니었다."),
    ("sorrow", "늦은 답장", "오래 연락하지 못한 친구에게 답장을 보냈다. 그동안 외로웠을 친구 생각에 마음이 아팠다. 서운했던 마음보다 보고 싶은 마음이 더 컸다는 걸 알았다."),
    ("calm", "첫눈 소식", "첫눈이 온다는 소식에 창문을 열어 두었다. 차가운 공기가 들어와도 마음은 편안했다. 계절이 바뀌는 걸 천천히 느끼는 것도 괜찮은 하루였다."),
    ("anger", "약속 시간", "친구가 또 늦었다. 기다리는 동안 짜증이 났는데 정리해 보면 내 시간이 가볍게 여겨지는 것 같아 억울했던 것 같다. 다음엔 그 마음을 말해 보려고 한다."),
    ("insight", "오래된 습관", "밤마다 휴대폰을 보다 잠드는 습관을 알아차렸다. 왜 그랬을까 생각해 보니 하루를 그냥 끝내기가 아쉬웠다. 내가 원했던 건 조금 더 나만의 시간이었다."),
    ("sorrow", "엄마의 목소리", "전화 너머 엄마 목소리가 조금 지쳐 보였다. 괜히 눈물이 나서 말을 아꼈다. 그립고 미안한 마음을 오늘은 짧은 문자로라도 전해야겠다."),
    ("calm", "따뜻한 국", "퇴근하고 국을 끓여 먹었다. 따뜻한 국물이 들어가니 하루가 조용히 풀리는 느낌이었다. 쉬어 가는 저녁이 고마웠다."),
]
NEBULA_NAMES = ["조용한 계절", "마음의 지도", "작은 용기들", "흐린 날의 빛", "나를 지나간 것들"]


def ensure_key(db, cipher: Cipher) -> None:
    """The key must open the stars already there, or the new ones would be unreadable to the server."""
    sample = db.scalars(select(Star).limit(5)).all()
    for s in sample:
        cipher.dec(s.title_enc)  # raises on a wrong key
    print(f"key ok ({len(sample)} existing stars opened)")


def seed_user(db, cipher: Cipher, user: User, rnd: random.Random, ids: dict,
              start: datetime | None = None, end: datetime | None = None, count: int = 10,
              stars_only: bool = False) -> None:
    """Dates fall between `start` and `end` (default: the last 40 days). Titles the account already has
    are not used again."""
    now = datetime.now(timezone.utc)
    end = end or now - timedelta(days=1)
    start = start or now - timedelta(days=40)
    have = {cipher.dec(t) for t in db.scalars(select(Star.title_enc).where(Star.user_id == user.id))}
    fresh = [w for w in WRITINGS if w[1] not in have]
    picks = rnd.sample(fresh if len(fresh) >= count else WRITINGS, count)
    stars = []
    for i, (mood, title, body) in enumerate(picks):
        at = start + timedelta(seconds=rnd.uniform(0, (end - start).total_seconds()))
        lit = i < 7
        star = Star(user_id=user.id, mood=mood, moods=[mood], title_enc=cipher.enc(title), body_enc=cipher.enc(body),
                    state="kept", created_at=at)
        if lit:
            analysis = to_analysis([mock_sample(title, body)], body)
            analysis["starlight"] = max(1, analysis["starlight"])
            star.state, star.floated_at, star.prism_version = "floated", at, PRISM_VERSION
            star.starlight, star.depth_score = analysis["starlight"], analysis["scores"]["depth"]
            star.analysis_enc = cipher.enc_json(analysis)
        db.add(star)
        stars.append((star, title, body, lit))
    db.flush()
    ids["stars"] += [s.id for s, *_ in stars]
    if stars_only:
        return

    lit_stars = sorted([s for s, _, _, lit in stars if lit], key=lambda s: s.created_at)[:4]
    nebula = Nebula(user_id=user.id, name=rnd.choice(NEBULA_NAMES), silhouette=None,
                    star_ids=[s.id for s in lit_stars], edges=[[0, 1], [1, 2], [2, 3]],
                    created_at=lit_stars[-1].created_at + timedelta(hours=1))
    db.add(nebula)
    db.flush()
    ids["nebulae"].append(nebula.id)
    shape = {"silhouette": None, "edges": nebula.edges,
             "stars": [{"mood": s.mood, "shape": cipher.dec_json(s.analysis_enc)["shape"],
                        "depth_level": cipher.dec_json(s.analysis_enc)["depth_level"]} for s in lit_stars]}
    depths = [st["depth_level"] for st in shape["stars"]]
    db.add(NebulaShare(nebula_id=nebula.id, user_id=user.id, name=privacy.scan(nebula.name)["masked"], shape=shape,
                       moods=list(dict.fromkeys(s.mood for s in lit_stars)), depth_level=round(sum(depths) / len(depths)),
                       quote=None))

    for k, (star, title, body, lit) in enumerate([x for x in stars if x[3]][:2]):
        full = k == 1
        mode = "contacts" if full else "all"
        quote = body.split(". ")[0] + "."
        a = cipher.dec_json(star.analysis_enc)
        share = StarShare(star_id=star.id, user_id=user.id, name=privacy.scan(title, mode)["masked"],
                          quote=privacy.scan(quote, mode)["masked"], full_text=full,
                          body_masked_enc=cipher.enc(privacy.scan(body, mode)["masked"]) if full else None,
                          receive_lines=True, mood=star.mood, moods=[star.mood], depth_level=a["depth_level"],
                          shape=a["shape"])
        db.add(share)
    db.flush()


def remove(db, path: str) -> None:
    ids = json.load(open(path))
    n = db.execute(delete(Nebula).where(Nebula.id.in_(ids["nebulae"]))).rowcount
    s = db.execute(delete(Star).where(Star.id.in_(ids["stars"]))).rowcount
    db.commit()
    print(f"removed {s} stars, {n} nebulae (shares went with them)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    ap.add_argument("--go", action="store_true")
    ap.add_argument("--remove")
    ap.add_argument("--start", help="ISO date-time, e.g. 2026-11-01T00:00:00+09:00")
    ap.add_argument("--end")
    ap.add_argument("--count", type=int, default=10)
    ap.add_argument("--stars-only", action="store_true", help="no nebula, no plaza shares")
    ap.add_argument("--provider", help="only accounts signed up with this provider (apple, google, …)")
    a = ap.parse_args()
    db = sessionmaker(make_engine(os.environ["DATABASE_URL"]))()
    cipher = Cipher(os.environ["DATA_ENCRYPTION_KEY"])
    ensure_key(db, cipher)
    if a.remove:
        remove(db, a.remove)
        return 0
    q = select(User).order_by(User.keeper_no)
    if a.provider:
        q = q.where(User.provider == a.provider)
    users = db.scalars(q).all()
    print("accounts:", [(u.keeper_no, u.provider, u.nickname) for u in users])
    if not a.go:
        return 0
    if not a.out:
        sys.exit("--out is required with --go")
    ids = {"stars": [], "nebulae": [], "created_at": datetime.now(timezone.utc).isoformat()}
    rnd = random.Random()
    for u in users:
        seed_user(db, cipher, u, rnd, ids, datetime.fromisoformat(a.start) if a.start else None,
                  datetime.fromisoformat(a.end) if a.end else None, a.count, a.stars_only)
    db.commit()
    with open(a.out, "w") as f:
        json.dump(ids, f, indent=1)
    print(f"seeded {len(users)} accounts: {len(ids['stars'])} stars, {len(ids['nebulae'])} nebulae; ids in {a.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
