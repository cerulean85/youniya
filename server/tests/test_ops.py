"""Rate limits, refund notifications, PDF export and the operator API."""

import jwt
from fastapi.testclient import TestClient

from youniya_api.ratelimit import RateLimiter
from youniya_api.storekit import StoreKitVerifier

from .conftest import CALM_BODY, float_star, sign_in
from .test_storekit import BUNDLE, FakeApple


def test_rate_limiter_window(make_app):
    limiter = RateLimiter(make_app().state.sessions)
    assert [limiter.hit("k", 2, 60, now=1000) for _ in range(2)] == [None, None]
    assert limiter.hit("k", 2, 60, now=1010) == 51  # the first hit leaves the window at 1060
    assert limiter.hit("other", 2, 60, now=1010) is None
    assert limiter.hit("k", 2, 60, now=1061) is None  # both early hits have expired


def test_limits_are_shared_between_instances(make_app):
    """Vercel runs several instances on one database: they count together."""
    a, b = make_app(), make_app()
    a.state.sessions = b.state.sessions
    one, two = RateLimiter(a.state.sessions), RateLimiter(b.state.sessions)
    assert one.hit("k", 2, 60) is None and two.hit("k", 2, 60) is None
    assert one.hit("k", 2, 60) > 0


def test_forwarded_ip_only_behind_a_proxy(make_app):
    from starlette.requests import Request

    from youniya_api.ratelimit import client_ip

    def ip(trust):
        app = make_app(trust_proxy=trust)
        return client_ip(Request({"type": "http", "app": app, "client": ("10.0.0.1", 1),
                                  "headers": [(b"x-forwarded-for", b"1.2.3.4, 10.0.0.1")]}))

    assert ip(True) == "1.2.3.4"
    assert ip(False) == "10.0.0.1"


def test_inquiries_are_limited(client):
    h = sign_in(client)
    body = {"kind": "other", "email": "a@b.co", "body": "문의"}
    codes = [client.post("/v1/inquiries", json=body, headers=h).status_code for _ in range(6)]
    assert codes == [201] * 5 + [429]
    r = client.post("/v1/inquiries", json=body, headers=h).json()["error"]
    assert r["code"] == "rate_limited" and r["retry_after"] > 0
    assert int(client.post("/v1/inquiries", json=body, headers=h).headers["Retry-After"]) > 0


def _refund_note(apple, transaction_id, bundle=BUNDLE, kind="REFUND"):
    tx = apple.jws(transactionId=transaction_id, revocationDate=1_800_000_000_000)
    return apple.sign({"notificationType": kind, "notificationUUID": "n1",
                       "data": {"bundleId": bundle, "signedTransactionInfo": tx}})


def test_refund_takes_coins_back(make_app):
    apple = FakeApple()
    app = make_app(trust_purchases=False, apple_bundle_id=BUNDLE)
    app.state.storekit = StoreKitVerifier(BUNDLE, root=apple.root)
    client = TestClient(app)
    h = sign_in(client)
    client.post("/v1/coins/purchases", json={"signed_transaction": apple.jws(transactionId="900")}, headers=h)
    assert client.get("/v1/coins", headers=h).json()["coins"] == 120

    url = "/v1/storekit/notifications"
    assert client.post(url, json={"signedPayload": _refund_note(apple, "900")}).json() == {"handled": True}
    # Apple may send the same notification again: refunded once.
    client.post(url, json={"signedPayload": _refund_note(apple, "900")})
    assert client.get("/v1/coins", headers=h).json()["coins"] == 0
    history = client.get("/v1/coins/history", headers=h).json()["items"]
    assert [(e["kind"], e["delta"]) for e in history] == [("refund", -120), ("purchase", 120)]

    assert client.post(url, json={"signedPayload": _refund_note(apple, "unknown")}).json()["handled"] is False
    assert client.post(url, json={"signedPayload": _refund_note(apple, "900", kind="TEST")}).json()["handled"] is False
    assert client.post(url, json={"signedPayload": _refund_note(FakeApple(), "900")}).status_code == 400
    assert client.post(url, json={"signedPayload": _refund_note(apple, "900", bundle="x")}).status_code == 400


def test_pdf_export(client):
    h = sign_in(client)
    float_star(client, h, body=CALM_BODY, title="느리게 흘러간 하루", mood="calm")
    r = client.get("/v1/me/export", params={"format": "pdf"}, headers=h)
    assert r.status_code == 200 and r.headers["content-type"] == "application/pdf"
    assert r.content.startswith(b"%PDF") and b"NanumGothic" in r.content


def test_operator_api(make_app):
    client = TestClient(make_app(admin_token="op-token"))
    owner, writer, reporter = sign_in(client, "a"), sign_in(client, "b"), sign_in(client, "c")
    ids = [float_star(client, owner)["id"] for _ in range(3)]
    n = client.post("/v1/nebulae", json={"name": "성운", "star_ids": ids}, headers=owner).json()
    share = client.put(f"/v1/nebulae/{n['id']}/share", json={}, headers=owner).json()
    line = client.post(f"/v1/plaza/nebulae/{share['share_id']}/lines", json={"text": "광고 보러 오세요"},
                       headers=writer).json()
    client.post(f"/v1/plaza/lines/{line['id']}/report", json={"reason": "spam"}, headers=reporter)

    op = {"X-Admin-Token": "op-token"}
    assert client.get("/v1/admin/reports").status_code == 404
    assert client.get("/v1/admin/reports", headers={"X-Admin-Token": "wrong"}).status_code == 404
    reports = client.get("/v1/admin/reports", headers=op).json()["items"]
    assert reports[0]["line_id"] == line["id"] and reports[0]["reasons"] == {"spam": 1}

    client.post(f"/v1/admin/lines/{line['id']}/hide", headers=op)
    assert client.get(f"/v1/plaza/nebulae/{share['share_id']}/lines", headers=writer).json()["items"] == []

    actions = [e["action"] for e in client.get("/v1/admin/logs", headers=op).json()["items"]]
    assert actions == ["hide_line", "list_reports"]
    # Without ADMIN_TOKEN the operator API does not exist.
    assert TestClient(make_app()).get("/v1/admin/logs", headers=op).status_code == 404


def test_refund_never_goes_below_zero(make_app):
    """기획서 11.6: only the coins left are taken back; the balance stops at 0."""
    apple = FakeApple()
    app = make_app(trust_purchases=False, apple_bundle_id=BUNDLE)
    app.state.storekit = StoreKitVerifier(BUNDLE, root=apple.root)
    client = TestClient(app)
    h = sign_in(client)
    client.post("/v1/coins/purchases", json={"signed_transaction": apple.jws(transactionId="77")}, headers=h)
    float_star(client, h)
    for _ in range(2):
        client.post("/v1/telescope/reports", json={}, headers=h)  # free: this month's and the sign-up one
    for _ in range(4):
        assert client.post("/v1/telescope/reports", json={}, headers=h).status_code == 201  # 80 spent
    assert client.get("/v1/coins", headers=h).json()["coins"] == 40

    client.post("/v1/storekit/notifications", json={"signedPayload": _refund_note(apple, "77")})
    assert client.get("/v1/coins", headers=h).json()["coins"] == 0
    refund = client.get("/v1/coins/history", headers=h).json()["items"][0]
    assert (refund["kind"], refund["delta"]) == ("refund", -40)


def test_balance_constraint_and_startup_fix(make_app):
    import pytest
    from sqlalchemy import text
    from sqlalchemy.exc import IntegrityError

    app = make_app()
    client = TestClient(app)
    sign_in(client)
    with app.state.sessions() as db:
        with pytest.raises(IntegrityError):
            db.execute(text("UPDATE users SET coins = -1"))
            db.commit()


def test_empty_refund_row_is_hidden_but_kept(make_app):
    """Nothing left to take back: no −0 row in the history, yet a second REFUND still changes nothing."""
    apple = FakeApple()
    app = make_app(trust_purchases=False, apple_bundle_id=BUNDLE)
    app.state.storekit = StoreKitVerifier(BUNDLE, root=apple.root)
    client = TestClient(app)
    h = sign_in(client)
    client.post("/v1/coins/purchases", json={"signed_transaction": apple.jws(transactionId="88", productId="coin_50")},
                headers=h)
    float_star(client, h)
    client.post("/v1/telescope/reports", json={}, headers=h)  # free
    client.post("/v1/telescope/reports", json={}, headers=h)  # the sign-up one, free too
    with app.state.sessions() as db:  # spend the rest some other way
        from sqlalchemy import update

        from youniya_api.models import User
        db.execute(update(User).values(coins=0))
        db.commit()

    for _ in range(2):
        client.post("/v1/storekit/notifications", json={"signedPayload": _refund_note(apple, "88")})
    kinds = [e["kind"] for e in client.get("/v1/coins/history", headers=h).json()["items"]]
    assert "refund" not in kinds
    with app.state.sessions() as db:
        from sqlalchemy import select

        from youniya_api.models import CoinEntry
        rows = db.scalars(select(CoinEntry).where(CoinEntry.transaction_id == "refund:88")).all()
        assert [r.delta for r in rows] == [0]


def test_error_reports_carry_no_writing():
    from youniya_api.monitoring import scrub

    secret = "걔 소식 듣고 속이 쓰렸다"
    event = {
        "request": {"url": "https://api/v1/stars", "data": {"body": secret}, "query_string": f"q={secret}",
                    "cookies": {"a": "b"}, "headers": {"Authorization": "Bearer t", "X-Admin-Token": "op",
                                                        "User-Agent": "YOUNIYA/1.0"}},
        "exception": {"values": [{"type": "ValidationError", "value": f"input_value='{secret}'",
                                  "stacktrace": {"frames": [{"function": "evaluate", "vars": {"body": secret}}]}}]},
        "logentry": {"message": "prism reading failed: %s", "params": [secret], "formatted": secret},
        "breadcrumbs": {"values": [{"message": secret}]},
        "extra": {"body": secret},
    }
    out = scrub(event)
    assert secret not in repr(out)
    assert out["request"]["headers"] == {"User-Agent": "YOUNIYA/1.0"}
    assert out["exception"]["values"][0]["type"] == "ValidationError"
    assert out["exception"]["values"][0]["stacktrace"]["frames"][0]["function"] == "evaluate"
