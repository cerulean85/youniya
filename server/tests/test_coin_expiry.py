"""코인 소멸 (2026-12-01 시행): a year with no charge or use, notices 30 and 7 days before (Apple Expiring Consumables).
App Store coins of the current products never expire (사용자 결정 2026-11-19). Coins go oldest first."""

from datetime import date, datetime, timezone

import jwt
import sqlalchemy as sa

from youniya_api import coins
from youniya_api.models import CoinEntry, CoinLot, User
from youniya_api.views import KST

from .conftest import sign_in
from .test_marketing import FakePush


def _at(y, m, d, hour=10):
    return datetime(y, m, d, hour, tzinfo=KST)


class Mails:
    def __init__(self):
        self.sent = []

    def __call__(self, key, sender, to, subject, text):
        self.sent.append((to, subject, text))
        return "id"


def _charge(client, sub, amount, tx, product="coin_110"):
    with client.app.state.sessions() as db:
        u = db.query(User).filter_by(provider_sub=sub).one()
        coins.add(db, u, amount, "코인 충전", transaction_id=tx, product_id=product)
        db.commit()


def _set_active(client, at):
    with client.app.state.sessions() as db:
        db.query(User).one().coins_active_at = at
        db.commit()


def _run(client, now, mails=None):
    s = client.app.state
    with s.sessions() as db:
        return coins.expire_due(db, s.push, s.cipher, s.settings, now=now, send_mail=mails or Mails())


def _lots(client):
    with client.app.state.sessions() as db:
        return [(l.source, l.expires, l.remaining) for l in db.query(CoinLot).order_by(CoinLot.created_at)]


def test_last_day_counts_from_the_policy_start_and_from_activity():
    u = User(coins=10, coins_active_at=None)
    assert coins.last_day(u) == date(2027, 12, 1)  # before 2026-12-01 counts from that day
    u.coins_active_at = _at(2026, 11, 20)
    assert coins.last_day(u) == date(2027, 12, 1)
    u.coins_active_at = _at(2027, 3, 5, hour=23)  # the Korean day, not UTC's
    assert coins.last_day(u) == date(2028, 3, 5)
    u.coins_active_at = _at(2028, 2, 29)
    assert coins.last_day(u) == date(2029, 2, 28)


def test_app_store_coins_of_current_products_never_expire(client):
    h = sign_in(client)
    client.post("/v1/coins/purchases", json={"product_id": "coin_110", "transaction_id": "t1"}, headers=h)
    r = client.get("/v1/coins", headers=h).json()
    assert r["coins"] == 110 and r["coins_expiring"] == 0 and r["coins_expire_after"] is None
    _charge(client, "user-1", 50, "gp:o1")
    r = client.get("/v1/coins", headers=h).json()
    assert r["coins_expiring"] == 50 and r["coins_expire_after"] >= "2027-12-01"
    _charge(client, "user-1", 20, "a-new-expiring", product="coin_110_y")  # a future expiring App Store product
    assert _lots(client)[-1] == ("app_store", True, 20)
    _set_active(client, _at(2027, 1, 10))
    assert _run(client, _at(2028, 1, 11))["expired"] == 1
    with client.app.state.sessions() as db:
        assert db.query(User).one().coins == 110
        assert db.query(CoinEntry).filter_by(title=coins.EXPIRED_TITLE).one().delta == -70


def test_spend_is_oldest_first_and_a_cancel_puts_coins_back(client):
    sign_in(client)
    _charge(client, "user-1", 10, "t-app")  # App Store, never expires, oldest
    _charge(client, "user-1", 10, "gp:o1")
    with client.app.state.sessions() as db:
        u = db.query(User).one()
        lots = coins.spend(db, u, 15, "별 띄우기")
        db.commit()
    assert [x[2] for x in _lots(client)] == [0, 5]
    with client.app.state.sessions() as db:
        u = db.query(User).one()
        coins.give_back(db, u, lots, 15, "별빛 받기 그만두기")
        db.commit()
        assert u.coins == 20
    assert _lots(client) == [("app_store", False, 10), ("google_play", True, 10)]


def test_refund_takes_its_own_purchase_first(client):
    sign_in(client)
    _charge(client, "user-1", 10, "gp:o1")
    _charge(client, "user-1", 10, "t-app")
    with client.app.state.sessions() as db:
        u = db.query(User).one()
        assert coins.take_back(db, u, 10, "환불", transaction_id="refund:t-app") == 10
        db.commit()
    assert _lots(client) == [("google_play", True, 10), ("app_store", False, 0)]


def test_notices_then_expiry(make_app):
    from fastapi.testclient import TestClient

    client = TestClient(make_app(resend_api_key="rk"))
    client.app.state.push = FakePush()
    token = jwt.encode({"sub": "apple-1", "email": "Me@privaterelay.appleid.com"}, "k" * 32, algorithm="HS256")
    h = sign_in(client, token)
    _charge(client, token, 30, "toss:o1")
    _charge(client, token, 5, "t-app")  # App Store: not counted, not taken
    _set_active(client, _at(2027, 1, 10))  # last day 2028-01-10
    with client.app.state.sessions() as db:
        assert client.app.state.cipher.dec(db.query(User).one().email_enc) == "me@privaterelay.appleid.com"

    mails = Mails()
    assert _run(client, _at(2027, 12, 1), mails) == {"notified": 0, "expired": 0}
    assert _run(client, _at(2027, 12, 11), mails) == {"notified": 1, "expired": 0}  # 30 days left
    assert _run(client, _at(2027, 12, 12), mails)["notified"] == 0  # once
    assert _run(client, _at(2028, 1, 3), mails)["notified"] == 1  # 7 days left
    assert len(mails.sent) == 2 and mails.sent[0][0] == "me@privaterelay.appleid.com"
    assert "2028년 1월 10일" in mails.sent[1][2] and "30개" in mails.sent[1][2]
    titles = [n["title"] for n in client.get("/v1/me/notifications", headers=h).json()["items"]]
    assert titles.count("코인 소멸 예정 안내") == 2

    assert _run(client, _at(2028, 1, 10), mails)["expired"] == 0  # still usable that day
    assert _run(client, _at(2028, 1, 11), mails) == {"notified": 0, "expired": 1}
    with client.app.state.sessions() as db:
        assert db.query(User).one().coins == 5
        assert db.query(CoinEntry).filter_by(title=coins.EXPIRED_TITLE).one().delta == -30
    assert _run(client, _at(2028, 1, 12), mails)["expired"] == 0


def test_a_charge_restarts_the_year_and_the_notices(client):
    client.app.state.push = FakePush()
    sign_in(client)
    _charge(client, "user-1", 30, "gp:o1")
    _set_active(client, _at(2027, 1, 10))
    assert _run(client, _at(2028, 1, 5))["notified"] == 1  # a late start: only the 7-day one
    assert _run(client, _at(2028, 1, 6))["notified"] == 0
    _charge(client, "user-1", 10, "gp:o2")
    with client.app.state.sessions() as db:
        assert db.query(User).one().coins_notice_days is None
    _set_active(client, _at(2028, 1, 6))  # the charge's day, as if it were then
    assert _run(client, _at(2028, 1, 11))["expired"] == 0


def test_migration_backfills_lots_from_history(tmp_path):
    from alembic import command
    from alembic.config import Config

    url = f"sqlite:///{tmp_path}/m.db"
    from .migrate import INI

    cfg = Config(str(INI))
    cfg.attributes["url"] = url
    command.upgrade(cfg, "5c9e2a7d4b13")
    e = sa.create_engine(url)
    with e.begin() as c:
        c.execute(sa.text("INSERT INTO users (id, provider, provider_sub, created_at, settings, coins, "
                          "marketing_opt_in, free_telescope_used, free_star_count, free_story_used, member_star_count, "
                          "member_telescope_count, member_story_count) VALUES ('u', 'apple', 's', '2026-11-01', "
                          "'{}', 15, 0, 0, 0, 0, 0, 0, 0)"))
        for i, (delta, tx, at) in enumerate([(10, "t-app", "2026-11-02"), (10, "gp:o", "2026-11-03"),
                                             (-5, None, "2026-11-04")]):
            c.execute(sa.text("INSERT INTO coin_entries (id, user_id, title, delta, transaction_id, created_at) "
                              "VALUES (:i, 'u', 'x', :d, :t, :a)"), {"i": f"e{i}", "d": delta, "t": tx, "a": at})
    command.upgrade(cfg, "8d1f3b6e2a47")
    with e.connect() as c:
        rows = c.execute(sa.text("SELECT source, expires, remaining FROM coin_lots ORDER BY created_at")).all()
    assert [(s, bool(x), r) for s, x, r in rows] == [("app_store", False, 5), ("google_play", True, 10)]
