"""관리자 콘솔 owner 화면 (18장, step 7-3)."""

from fastapi.testclient import TestClient

from youniya_api.models import AiUsage

from .conftest import CALM_BODY, float_star, sign_in
from .test_admin_auth import _operator, _sign_in


def _setup(make_app, **kw):
    client = TestClient(make_app(admin_token="op-token", **kw))
    oh, _ = _sign_in(client, _operator(client))
    mh, _ = _sign_in(client, _operator(client, "mod@youniya.app", "moderator", oh), "mod@youniya.app")
    return client, oh, mh


def test_owner_only(make_app):
    client, oh, mh = _setup(make_app)
    for path in ("/v1/admin/dashboard", "/v1/admin/coins", "/v1/admin/ai", "/v1/admin/prism", "/v1/admin/invites",
                 "/v1/admin/notices"):
        assert client.get(path, headers=mh).status_code == 403, path
        assert client.get(path, headers=oh).status_code == 200, path


def test_dashboard_and_ledger(make_app):
    client, oh, _ = _setup(make_app)
    h = sign_in(client)
    float_star(client, h)
    client.post("/v1/stars", json={"mood": "calm", "body": CALM_BODY, "mode": "unlit"}, headers=h)
    client.post("/v1/coins/purchases", json={"signed_transaction": "t1", "product_id": "coin_110"}, headers=h)
    d = client.get("/v1/admin/dashboard", headers=oh).json()
    assert d["stars"] == {"lit": 1, "unlit": 1, "total": 2} and d["new_keepers"] >= 1
    ledger = client.get("/v1/admin/coins", headers=oh).json()
    assert ledger["month"] and isinstance(ledger["items"], list)


def test_ai_usage_per_feature(make_app):
    client, oh, _ = _setup(make_app)
    with client.app.state.sessions() as db:
        db.add(AiUsage(month=__import__("youniya_api.allowance", fromlist=["x"]).this_month(), feature="prism",
                       attempts=0, failures=0, calls=4, input_tokens=4000, cached_tokens=1000, output_tokens=800,
                       krw=33.6, requests=4))
        db.commit()
    ai = client.get("/v1/admin/ai", headers=oh).json()
    p = next(f for f in ai["features"] if f["feature"] == "prism")
    assert p["krw_per_request"] == 8.4 and p["cache_hit_rate"] == 0.25 and p["avg_output_tokens"] == 200


def test_invites_from_the_console(make_app):
    client, oh, _ = _setup(make_app, invite_login=True)
    r = client.post("/v1/admin/invites", json={"login_id": "reviewer2", "memo": "심사", "reason": "제출 준비"}, headers=oh)
    assert r.status_code == 201 and r.json()["password"]
    pw = r.json()["password"]
    assert client.post("/v1/auth/invite", json={"login": "reviewer2", "password": pw}).status_code == 200
    client.patch("/v1/admin/invites/reviewer2", json={"enabled": False, "reason": "끝남"}, headers=oh)
    assert client.post("/v1/auth/invite", json={"login": "reviewer2", "password": pw}).status_code == 401
    client.patch("/v1/admin/invites/reviewer2", json={"enabled": True, "reason": "다시"}, headers=oh)
    client.put("/v1/admin/invites/settings", json={"enabled": False, "reason": "심사 끝"}, headers=oh)
    assert client.post("/v1/auth/invite", json={"login": "reviewer2", "password": pw}).status_code == 404
    assert client.get("/v1/admin/invites", headers=oh).json()["enabled"] is False
    assert client.post("/v1/admin/invites/reviewer2/reseed", headers=oh).json()["error"]["code"] == "manual_only"


def test_maintenance_min_version_and_notices(make_app):
    client, oh, _ = _setup(make_app)
    h = sign_in(client)
    on = client.put("/v1/admin/maintenance", json={"on": True, "reason": "DB 작업"}, headers=oh).json()
    assert on["on"] is True and on["end"]
    r = client.get("/v1/me", headers=h)
    assert r.status_code == 503 and r.json()["error"]["code"] == "maintenance"
    assert client.get("/v1/app/status").json()["in_maintenance"] is True
    assert client.get("/v1/admin/notices", headers=oh).status_code == 200  # operators still get in
    client.put("/v1/admin/maintenance", json={"on": False, "reason": "끝"}, headers=oh)
    assert client.get("/v1/me", headers=h).status_code == 200

    client.put("/v1/admin/min-version", json={"ios": "9.0.0", "reason": "필수 업데이트"}, headers=oh)
    assert client.get("/v1/me", headers=h | {"X-App-Version": "1.2.0"}).status_code == 426
    assert client.get("/v1/app/status", params={"version": "1.2.0"}).json()["update_required"] is True
    client.put("/v1/admin/min-version", json={"ios": "1.0.0", "reason": "되돌림"}, headers=oh)

    n = client.post("/v1/admin/notices", json={"title": "점검 안내", "body": "11일 새벽에 점검해요.", "reason": "공지"},
                    headers=oh).json()
    assert n["published"] is True
    later = client.post("/v1/admin/notices", json={"title": "예약", "body": "나중", "publish_at": "2099-01-01T00:00:00+00:00",
                                                   "reason": "예약"}, headers=oh).json()
    items = client.get("/v1/notices", headers=h).json()["items"]
    assert [i["title"] for i in items] == ["점검 안내"] and later["published"] is False
    actions = [a["action"] for a in client.get("/v1/admin/audit", headers=oh).json()["items"]]
    assert {"maintenance_on", "maintenance_off", "min_version", "notice_post"} <= set(actions)


def test_min_version_is_for_ios_only(make_app):
    client, oh, _ = _setup(make_app)
    h = sign_in(client)
    client.put("/v1/admin/min-version", json={"ios": "9.0.0", "reason": "필수 업데이트"}, headers=oh)
    assert client.get("/v1/me", headers=h | {"X-App-Version": "0.3.0"}).status_code == 426
    assert client.get("/v1/me", headers=h | {"X-App-Version": "0.3.0", "X-App-Platform": "ios"}).status_code == 426
    assert client.get("/v1/me", headers=h | {"X-App-Version": "0.3.0", "X-App-Platform": "web"}).status_code == 200
