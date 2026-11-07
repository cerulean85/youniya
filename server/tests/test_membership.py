"""별지기 멤버십 (v1.1, MEMBERSHIP=1): purchase, notifications, what a member gets, 월간 마음 리포트."""

import time

from fastapi.testclient import TestClient

from youniya_api.allowance import this_month
from youniya_api.storekit import StoreKitVerifier

from .conftest import DEEP_BODY, float_star, sign_in
from .test_storekit import BUNDLE, FakeApple

URL = "/v1/storekit/notifications"


def _app(make_app, **kw):
    apple = FakeApple()
    app = make_app(**{"membership": True, "apple_bundle_id": BUNDLE, "free_stars_per_day": 1} | kw)
    app.state.storekit = StoreKitVerifier(BUNDLE, root=apple.root)
    return apple, TestClient(app)


def _tx(user_id, days=30, **kw):
    return {"bundleId": BUNDLE, "productId": "membership_monthly", "type": "Auto-Renewable Subscription",
            "transactionId": "t1", "originalTransactionId": "o1", "environment": "Sandbox",
            "expiresDate": int((time.time() + days * 86400) * 1000), "appAccountToken": user_id} | kw


def _note(apple, kind, tx, subtype=None, renew=None):
    data = {"bundleId": BUNDLE, "signedTransactionInfo": apple.sign(tx)}
    if renew is not None:
        data["signedRenewalInfo"] = apple.sign({"autoRenewStatus": renew})
    return {"signedPayload": apple.sign({"notificationType": kind, "subtype": subtype, "data": data})}


def _join(apple, client, h):
    user_id = client.get("/v1/me", headers=h).json()["id"]
    r = client.post("/v1/membership/verify", json={"signedTransaction": apple.sign(_tx(user_id))}, headers=h)
    assert r.status_code == 200, r.text
    return user_id, r.json()


def test_everything_is_hidden_while_off(client):
    h = sign_in(client)
    assert "membership" not in client.get("/v1/me", headers=h).json()
    for path in ("/v1/membership", "/v1/reports/monthly"):
        assert client.get(path, headers=h).status_code == 404
    assert client.post("/v1/membership/verify", json={"signedTransaction": "x"}, headers=h).status_code == 404


def test_member_gets_unlimited_stars_story_15_telescopes_and_every_sky(make_app):
    apple, client = _app(make_app)
    h = sign_in(client)
    assert client.get("/v1/membership", headers=h).json()["active"] is False
    assert client.patch("/v1/me/settings", json={"sky": "rose"}, headers=h).status_code == 403

    user_id, joined = _join(apple, client, h)
    assert joined | {"expires_at": None} == {"active": True, "product_id": "membership_monthly", "expires_at": None,
                                             "auto_renew": True, "status": "active", "telescope_left_this_month": 15}
    me = client.get("/v1/me", headers=h).json()
    assert me["membership"]["active"] is True and me["free_telescope"] == 17  # 15 + this month's + sign-up

    charged = [client.post("/v1/stars", json={"mood": "insight", "title": "t", "body": DEEP_BODY, "mode": "float"},
                           headers=h).json()["charged"] for _ in range(3)]
    assert charged == [0, 0, 0] and client.get("/v1/coins", headers=h).json()["coins"] == 0
    ids = [float_star(client, h)["id"] for _ in range(3)]
    for name in ("하나", "둘"):
        n = client.post("/v1/nebulae", json={"name": name, "star_ids": ids}, headers=h).json()
        assert client.post(f"/v1/nebulae/{n['id']}/story/polish", headers=h).json()["charged"] == 0
    assert client.patch("/v1/me/settings", json={"sky": "rose"}, headers=h).json()["sky"] == "rose"

    # The membership's 15 go first; the free monthly and sign-up ones are still there after.
    for _ in range(2):
        assert client.post("/v1/telescope/reports", json={}, headers=h).json()["charged"] == 0
    assert client.get("/v1/membership", headers=h).json()["telescope_left_this_month"] == 13
    with client.app.state.sessions() as db:  # the other 13 (the rate limit allows 10 an hour)
        from youniya_api.models import User

        db.get(User, user_id).member_telescope_count = 15
        db.commit()
    assert client.get("/v1/membership", headers=h).json()["telescope_left_this_month"] == 0
    assert client.get("/v1/telescope/offer", headers=h).json()["free_left"] == 2
    for _ in range(2):
        assert client.post("/v1/telescope/reports", json={}, headers=h).json()["charged"] == 0
    assert client.post("/v1/telescope/reports", json={}, headers=h).json()["error"]["cost"] == 20


def test_notifications_keep_the_subscription_current(make_app):
    apple, client = _app(make_app)
    h = sign_in(client)
    user_id, _ = _join(apple, client, h)
    client.patch("/v1/me/settings", json={"sky": "aurora"}, headers=h)

    assert client.post(URL, json=_note(apple, "DID_CHANGE_RENEWAL_STATUS", _tx(user_id), "AUTO_RENEW_DISABLED",
                                       renew=0)).json() == {"handled": True}
    assert client.get("/v1/membership", headers=h).json()["auto_renew"] is False
    renewed = _tx(user_id, days=60, transactionId="t2")
    client.post(URL, json=_note(apple, "DID_RENEW", renewed, renew=1))
    m = client.get("/v1/membership", headers=h).json()
    assert m["active"] is True and m["auto_renew"] is True

    client.post(URL, json=_note(apple, "EXPIRED", _tx(user_id, days=-1, transactionId="t2"), "VOLUNTARY"))
    me = client.get("/v1/me", headers=h).json()
    assert me["membership"]["active"] is False and me["settings"]["sky"] == "violet"  # the member sky goes

    client.post(URL, json=_note(apple, "SUBSCRIBED", _tx(user_id, transactionId="t3"), "RESUBSCRIBE"))
    assert client.get("/v1/membership", headers=h).json()["active"] is True
    client.post(URL, json=_note(apple, "REFUND", _tx(user_id, transactionId="t3", revocationDate=1)))
    assert client.get("/v1/membership", headers=h).json() | {"expires_at": None} == {
        "active": False, "product_id": "membership_monthly", "expires_at": None, "auto_renew": False,
        "status": "revoked", "telescope_left_this_month": 0}

    # Someone else's purchase cannot be claimed.
    other = sign_in(client, "other")
    r = client.post("/v1/membership/verify", json={"signedTransaction": apple.sign(_tx(user_id))}, headers=other)
    assert r.status_code == 409
    coins = client.post(URL, json=_note(apple, "REFUND", {"bundleId": BUNDLE, "productId": "coin_110",
                                                          "transactionId": "none"}))
    assert coins.json() == {"handled": False}  # the coin path is untouched


def test_monthly_report(make_app):
    apple, client = _app(make_app)
    h = sign_in(client)
    month = this_month()
    assert client.post("/v1/reports/monthly", json={"month": month}, headers=h).status_code == 403
    _join(apple, client, h)
    for _ in range(4):
        float_star(client, h)
    r = client.post("/v1/reports/monthly", json={"month": month}, headers=h)
    assert r.status_code == 422 and r.json()["error"]["needed"] == 5
    float_star(client, h, title="가장 밝은 별")
    report = client.post("/v1/reports/monthly", json={"month": month}, headers=h).json()
    assert report["month"] == month and report["star_count"] == 5 and report["title"].endswith("달")
    assert [lens["key"] for lens in report["lenses"]] == ["depth", "clarity", "weight"]
    assert report["brightest"]["sentence"] in DEEP_BODY and report["question"]
    # Asking again returns the same one; it is listed and can be opened.
    assert client.post("/v1/reports/monthly", json={"month": month}, headers=h).json()["id"] == report["id"]
    assert [i["month"] for i in client.get("/v1/reports/monthly", headers=h).json()["items"]] == [month]
    assert client.get(f"/v1/reports/monthly/{month}", headers=h).json()["id"] == report["id"]
    assert client.get("/v1/reports/monthly/2000-01", headers=h).status_code == 404


def test_season_silhouettes_are_for_members_and_stay(make_app):
    apple, client = _app(make_app, free_stars_per_day=10**6)
    h = sign_in(client)
    ids = [float_star(client, h)["id"] for _ in range(3)]
    body = {"name": "벚꽃 성운", "silhouette": "cherry_blossom", "star_ids": ids}
    r = client.post("/v1/nebulae", json=body, headers=h)
    assert r.status_code == 403 and r.json()["error"]["code"] == "member_only"
    assert client.post("/v1/nebulae", json=body | {"silhouette": "whale"}, headers=h).status_code == 201

    user_id, _ = _join(apple, client, h)
    n = client.post("/v1/nebulae", json=body, headers=h).json()
    share = client.put(f"/v1/nebulae/{n['id']}/share", json={}, headers=h).json()
    client.post(URL, json=_note(apple, "EXPIRED", _tx(user_id, days=-1)))
    # The membership ended: the saved nebula keeps its silhouette, and others see it on the plaza.
    assert client.get(f"/v1/nebulae/{n['id']}", headers=h).json()["silhouette"] == "cherry_blossom"
    seen = client.get(f"/v1/plaza/nebulae/{share['share_id']}", headers=sign_in(client, "other")).json()
    assert seen["shape"]["silhouette"] == "cherry_blossom"
