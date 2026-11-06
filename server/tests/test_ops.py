"""Rate limits, refund notifications, PDF export and the operator API."""

import jwt
from fastapi.testclient import TestClient

from youniya_api.ratelimit import RateLimiter
from youniya_api.storekit import StoreKitVerifier

from .conftest import CALM_BODY, float_star, sign_in
from .test_storekit import BUNDLE, FakeApple


def test_rate_limiter_window():
    limiter = RateLimiter()
    assert [limiter.hit("k", 2, 60) for _ in range(3)][:2] == [None, None]
    assert limiter.hit("k", 2, 60) > 0
    assert limiter.hit("other", 2, 60) is None


def test_inquiries_are_limited(client):
    h = sign_in(client)
    body = {"kind": "other", "email": "a@b.co", "body": "문의"}
    codes = [client.post("/v1/inquiries", json=body, headers=h).status_code for _ in range(6)]
    assert codes == [201] * 5 + [429]
    r = client.post("/v1/inquiries", json=body, headers=h).json()["error"]
    assert r["code"] == "rate_limited" and r["retry_after"] > 0


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
    assert [e["title"] for e in client.get("/v1/coins/history", headers=h).json()["items"]] == ["환불", "코인 충전"]

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
