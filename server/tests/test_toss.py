"""28 코인 충전 on the web: 토스페이먼츠 결제창, confirm, webhook and the 46 refund policy."""

from datetime import datetime, timedelta, timezone

import httpx
from fastapi.testclient import TestClient

from youniya_api.models import TossOrder
from youniya_api.toss import TossError

from .conftest import sign_in


class FakeToss:
    def __init__(self):
        self.payments: dict[str, dict] = {}  # paymentKey → payment
        self.fail: TossError | Exception | None = None
        self.confirms = 0
        self.cancels = 0

    def confirm(self, payment_key, order_id, amount):
        self.confirms += 1
        if self.fail:
            raise self.fail
        if payment_key in self.payments:
            raise TossError(400, "ALREADY_PROCESSED_PAYMENT", "이미 처리된 결제 입니다.")
        p = {"paymentKey": payment_key, "orderId": order_id, "totalAmount": amount, "status": "DONE",
             "method": "카드", "cancels": None}
        self.payments[payment_key] = p
        return p

    def payment(self, payment_key):
        if payment_key not in self.payments:
            raise TossError(404, "NOT_FOUND_PAYMENT", "존재하지 않는 결제 정보 입니다.")
        return self.payments[payment_key]

    def cancel(self, payment_key, reason, idempotency_key):
        self.cancels += 1
        if self.fail:
            raise self.fail
        p = self.payments[payment_key]
        p["status"], p["cancels"] = "CANCELED", [{"cancelAmount": p["totalAmount"]}]
        return p


def _setup(make_app):
    app = make_app(toss_secret_key="test_sk_fake", toss_client_key="test_ck_fake", toss_test_open=True)
    app.state.toss = fake = FakeToss()
    client = TestClient(app)
    return client, sign_in(client), fake


def _order(client, h, package="coin_330"):
    r = client.post("/v1/payments/toss/orders", json={"package_id": package}, headers=h)
    assert r.status_code == 201, r.text
    return r.json()


def _coins(client, h):
    return client.get("/v1/coins", headers=h).json()["coins"]


def test_packages_and_order(make_app):
    client, h, _ = _setup(make_app)
    r = client.get("/v1/payments/toss/packages", headers=h).json()
    assert [(p["id"], p["coins"], p["price"], p["bonus"]) for p in r["items"]] == [
        ("coin_110", 110, 1100, 0), ("coin_330", 330, 3300, 0), ("coin_1100", 1100, 9900, 100)]
    assert r["client_key"] == "test_ck_fake" and r["available"] is True
    o = _order(client, h)
    assert o["amount"] == 3300 and o["order_name"] == "코인 330개"
    assert 6 <= len(o["order_id"]) <= 64 and o["order_id"].isalnum()
    assert o["customer_key"].startswith("yk_") and "user" not in o["customer_key"]
    assert _order(client, h)["customer_key"] == o["customer_key"]  # stable per keeper
    assert client.post("/v1/payments/toss/orders", json={"package_id": "coin_50"}, headers=h).status_code == 422


def test_confirm_adds_coins_once(make_app):
    client, h, fake = _setup(make_app)
    before = _coins(client, h)
    o = _order(client, h)
    body = {"payment_key": "pk_1", "order_id": o["order_id"], "amount": 3300}
    r = client.post("/v1/payments/toss/confirm", json=body, headers=h)
    assert r.status_code == 200, r.text
    assert r.json() == {"coins": before + 330, "granted": 330, "order_id": o["order_id"], "already_processed": False}
    again = client.post("/v1/payments/toss/confirm", json=body, headers=h).json()
    assert again["granted"] == 0 and again["already_processed"] and again["coins"] == before + 330
    assert fake.confirms == 1
    items = client.get("/v1/coins/history", headers=h).json()["items"]
    assert items[0]["kind"] == "purchase" and items[0]["source"] == "toss" and items[0]["delta"] == 330


def test_confirm_refusals(make_app):
    client, h, fake = _setup(make_app)
    o = _order(client, h)
    url = "/v1/payments/toss/confirm"
    r = client.post(url, json={"payment_key": "pk", "order_id": o["order_id"], "amount": 100}, headers=h)
    assert r.status_code == 409 and r.json()["error"]["code"] == "amount_mismatch"
    r = client.post(url, json={"payment_key": "pk", "order_id": "nope", "amount": 3300}, headers=h)
    assert r.status_code == 404
    other = sign_in(client, sub="user-2")
    r = client.post(url, json={"payment_key": "pk", "order_id": o["order_id"], "amount": 3300}, headers=other)
    assert r.status_code == 404  # another keeper's order
    fake.fail = TossError(400, "REJECT_CARD_PAYMENT", "한도초과 혹은 잔액부족으로 결제에 실패했습니다.")
    r = client.post(url, json={"payment_key": "pk", "order_id": o["order_id"], "amount": 3300}, headers=h)
    assert r.status_code == 402
    assert r.json()["error"] == {"code": "payment_failed", "message": "한도초과 혹은 잔액부족으로 결제에 실패했습니다.",
                                 "toss_code": "REJECT_CARD_PAYMENT"}
    fake.fail = None  # the order can be paid again after a refused card
    r = client.post(url, json={"payment_key": "pk2", "order_id": o["order_id"], "amount": 3300}, headers=h)
    assert r.status_code == 200 and r.json()["granted"] == 330


def test_expired_order(make_app):
    client, h, _ = _setup(make_app)
    o = _order(client, h)
    with client.app.state.sessions() as db:
        db.get(TossOrder, o["order_id"]).expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
        db.commit()
    r = client.post("/v1/payments/toss/confirm", json={"payment_key": "pk", "order_id": o["order_id"], "amount": 3300},
                    headers=h)
    assert r.status_code == 404 and r.json()["error"]["code"] == "order_expired"


def test_lost_answer_is_confirmed_on_retry(make_app):
    client, h, fake = _setup(make_app)
    before = _coins(client, h)
    o = _order(client, h)
    body = {"payment_key": "pk_lost", "order_id": o["order_id"], "amount": 3300}
    real = fake.confirm

    def approve_then_drop(*a):
        real(*a)
        raise httpx.ReadTimeout("no answer")
    fake.confirm = approve_then_drop
    r = client.post("/v1/payments/toss/confirm", json=body, headers=h)
    assert r.status_code == 502 and _coins(client, h) == before
    fake.confirm = real  # Toss now answers ALREADY_PROCESSED_PAYMENT; the server reads the payment back
    r = client.post("/v1/payments/toss/confirm", json=body, headers=h)
    assert r.status_code == 200 and r.json()["granted"] == 330 and _coins(client, h) == before + 330


def test_webhook_done_and_canceled(make_app):
    client, h, fake = _setup(make_app)
    before = _coins(client, h)
    o = _order(client, h)
    fake.payments["pk_w"] = {"paymentKey": "pk_w", "orderId": o["order_id"], "totalAmount": 3300, "status": "DONE",
                             "method": "카드"}
    hook = "/v1/payments/toss/webhook"
    # The body is not trusted: a made-up payment is read back from Toss and not found.
    assert client.post(hook, json={"eventType": "PAYMENT_STATUS_CHANGED", "data": {"paymentKey": "fake"}}).json() == {
        "handled": False}
    assert client.post(hook, json={"eventType": "PAYMENT_STATUS_CHANGED", "data": {"paymentKey": "pk_w"}}).json()[
        "handled"]
    assert _coins(client, h) == before + 330
    fake.payments["pk_w"] |= {"status": "CANCELED", "cancels": [{"cancelAmount": 3300}]}
    assert client.post(hook, json={"eventType": "PAYMENT_STATUS_CHANGED", "data": {"paymentKey": "pk_w"}}).json()[
        "handled"]
    assert _coins(client, h) == before
    assert client.get("/v1/coins/history", headers=h).json()["items"][0] | {"id": "", "created_at": ""} == {
        "id": "", "created_at": "", "kind": "refund", "title": "환불", "delta": -330, "source": "toss"}


def test_cancel_policy(make_app):
    client, h, fake = _setup(make_app)
    before = _coins(client, h)
    o = _order(client, h)
    client.post("/v1/payments/toss/confirm", json={"payment_key": "pk_c", "order_id": o["order_id"], "amount": 3300},
                headers=h)
    url = f"/v1/payments/toss/{o['order_id']}/cancel"
    fake.fail = TossError(400, "NOT_CANCELABLE_PAYMENT", "취소 할 수 없는 결제 입니다.")
    assert client.post(url, json={}, headers=h).status_code == 402 and _coins(client, h) == before + 330
    fake.fail = None
    r = client.post(url, json={"reason": "단순 변심"}, headers=h).json()
    assert r["taken"] == 330 and r["coins"] == before and fake.cancels == 2
    assert client.post(url, json={}, headers=h).json()["already_processed"] is True

    o2 = _order(client, h, "coin_110")
    client.post("/v1/payments/toss/confirm", json={"payment_key": "pk_d", "order_id": o2["order_id"], "amount": 1100},
                headers=h)
    with client.app.state.sessions() as db:  # some of the coins spent
        from youniya_api.models import User
        u = db.query(User).first()
        u.coins = before + 109
        db.commit()
    r = client.post(f"/v1/payments/toss/{o2['order_id']}/cancel", json={}, headers=h)
    assert r.status_code == 409 and r.json()["error"]["code"] == "coins_spent"


def test_without_key_web_payments_are_off(make_app):
    client = TestClient(make_app())
    h = sign_in(client)
    assert client.get("/v1/payments/toss/packages", headers=h).json()["available"] is False
    r = client.post("/v1/payments/toss/orders", json={"package_id": "coin_110"}, headers=h)
    assert r.status_code == 503 and r.json()["error"]["code"] == "payments_unavailable"
    assert client.post("/v1/payments/toss/webhook", json={"eventType": "PAYMENT_STATUS_CHANGED"}).status_code == 404


def test_test_key_is_for_accounts_made_before_the_cutoff(make_app):
    from youniya_api.models import User
    cutoff = datetime.now(timezone.utc)
    app = make_app(toss_secret_key="test_sk_fake", toss_test_accounts_before=cutoff)
    app.state.toss = FakeToss()
    client = TestClient(app)
    old = sign_in(client, sub="old")
    with app.state.sessions() as db:  # made before the cutoff
        db.query(User).update({User.created_at: cutoff - timedelta(days=1)})
        db.commit()
    new = sign_in(client, sub="new")  # made after it
    assert client.get("/v1/payments/toss/packages", headers=old).json()["available"] is True
    assert client.post("/v1/payments/toss/orders", json={"package_id": "coin_110"}, headers=old).status_code == 201
    assert client.get("/v1/payments/toss/packages", headers=new).json()["available"] is False
    r = client.post("/v1/payments/toss/orders", json={"package_id": "coin_110"}, headers=new)
    assert r.status_code == 403 and r.json()["error"]["code"] == "payments_not_open"
    with app.state.sessions() as db:  # named one by one
        new_id = db.query(User).filter(User.provider_sub == "new").one().id
    named = make_app(toss_secret_key="test_sk_fake", toss_test_accounts_before=cutoff, toss_test_user_ids=(new_id,))
    named.state.toss = FakeToss()
    nc = TestClient(named)
    assert nc.get("/v1/payments/toss/packages", headers=new).json()["available"] is True
    unset = make_app(toss_secret_key="test_sk_fake")
    unset.state.toss = FakeToss()
    uc = TestClient(unset)
    assert uc.get("/v1/payments/toss/packages", headers=sign_in(uc, sub="old")).json()["available"] is False
    live = make_app(toss_secret_key="live_sk_fake")
    live.state.toss = FakeToss()
    lc = TestClient(live)
    assert lc.get("/v1/payments/toss/packages", headers=sign_in(lc, sub="user-9")).json()["available"] is True


def test_refused_payment_key_can_be_used_by_no_other_order_but_frees_its_own(make_app):
    client, h, fake = _setup(make_app)
    a, b = _order(client, h, "coin_110"), _order(client, h, "coin_110")
    fake.fail = TossError(400, "NOT_FOUND_PAYMENT_SESSION", "결제 시간이 만료되어 결제 진행 데이터가 존재하지 않습니다.")
    for o in (a, b):  # a refused key is let go, so a second order with it is refused by Toss, not a 500
        r = client.post("/v1/payments/toss/confirm", json={"payment_key": "pk_same", "order_id": o["order_id"],
                                                          "amount": 1100}, headers=h)
        assert r.status_code == 402
    fake.fail = None
    client.post("/v1/payments/toss/confirm", json={"payment_key": "pk_same", "order_id": a["order_id"],
                                                   "amount": 1100}, headers=h)
    r = client.post("/v1/payments/toss/confirm", json={"payment_key": "pk_same", "order_id": b["order_id"],
                                                       "amount": 1100}, headers=h)
    assert r.status_code == 409 and r.json()["error"]["code"] == "payment_key_used"
