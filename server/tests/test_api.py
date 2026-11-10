from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from .conftest import CALM_BODY, DEEP_BODY, float_star, sign_in

CONSENT = {"terms": True, "privacy": True, "sensitive": True}


# --- auth, consent, app gate -------------------------------------------------

def test_sign_in_refresh_and_logout(client):
    r = client.post("/v1/auth/apple", json={"id_token": "u"})
    assert r.status_code == 200 and r.json()["needs_consent"] is True
    refresh = r.json()["refresh_token"]
    again = client.post("/v1/auth/refresh", json={"refresh_token": refresh})
    assert again.status_code == 200
    # Rotated: the old refresh token no longer works.
    assert client.post("/v1/auth/refresh", json={"refresh_token": refresh}).json()["error"]["code"] == "token_expired"
    assert client.post("/v1/auth/apple", json={"id_token": "bad"}).status_code == 401
    assert client.get("/v1/me").json()["error"]["code"] == "unauthorized"


def test_nothing_is_written_before_consent(client):
    h = sign_in(client, consent=False)
    r = client.post("/v1/stars", json={"mood": "calm", "body": CALM_BODY, "mode": "keep"}, headers=h)
    assert r.status_code == 403 and r.json()["error"]["code"] == "consent_required"
    assert client.post("/v1/me/consent", json={**CONSENT, "sensitive": False}, headers=h).status_code == 422
    assert client.post("/v1/me/consent", json=CONSENT, headers=h).status_code == 200
    assert client.get("/v1/me", headers=h).json()["needs_consent"] is False


def test_update_required_and_maintenance(make_app):
    now = datetime.now(timezone.utc)
    client = TestClient(make_app(min_app_version="2.0.0", maintenance_start=now - timedelta(hours=1),
                                 maintenance_end=now + timedelta(hours=1)))
    assert client.get("/v1/me").status_code == 503
    status = client.get("/v1/app/status", params={"version": "1.4.0"}).json()
    assert status["update_required"] is True and status["in_maintenance"] is True

    client = TestClient(make_app(min_app_version="2.0.0"))
    r = client.get("/v1/me", headers={"X-App-Version": "1.9.9"})
    assert r.status_code == 426 and r.json()["error"]["code"] == "update_required"


# --- stars -------------------------------------------------------------------

def test_float_keep_and_short_text(client):
    h = sign_in(client)
    star = float_star(client, h)
    assert star["state"] == "floated" and star["starlight"] >= 900
    assert star["analysis"]["impact_quote"] in DEEP_BODY

    # 104: too short to float; nothing is stored.
    r = client.post("/v1/stars", json={"mood": "calm", "body": "오늘은 그냥 좀 지쳤어요.", "mode": "float"}, headers=h)
    assert r.status_code == 422 and r.json()["error"]["code"] == "too_short"
    # …but it can be kept quietly.
    kept = client.post("/v1/stars", json={"mood": "calm", "body": "오늘은 그냥 좀 지쳤어요.", "mode": "keep"},
                       headers=h).json()["star"]
    assert kept["state"] == "kept" and kept["title"] == "제목 없는 별"

    summary = client.get("/v1/stars/summary", headers=h).json()
    assert (summary["total"], summary["floated"], summary["kept"], summary["supernova"]) == (2, 1, 1, 1)


def test_crisis_saves_the_writing_without_scoring(client):
    h = sign_in(client)
    body = CALM_BODY + " 요즘은 그냥 사라지고 싶다는 생각이 들어요."
    r = client.post("/v1/stars", json={"mood": "sorrow", "body": body, "mode": "float"}, headers=h).json()
    assert r["crisis"]["contacts"][0]["phone"] == "109"
    assert r["star"]["state"] == "kept" and r["star"]["analysis"] is None
    # …and it can't be shared.
    assert client.put(f"/v1/stars/{r['star']['id']}/share", json={"quote": "오늘은"}, headers=h).status_code == 422


def test_failed_analysis_keeps_the_star_and_can_retry(client, monkeypatch):
    h = sign_in(client)
    engine = client.app.state.prism
    real = engine._samples
    monkeypatch.setattr(engine, "_samples", lambda *a: (_ for _ in ()).throw(RuntimeError("down")))
    star = client.post("/v1/stars", json={"mood": "calm", "body": CALM_BODY, "mode": "float"}, headers=h).json()["star"]
    assert star["state"] == "kept" and star["analysis_failed"] is True
    assert client.post(f"/v1/stars/{star['id']}/float", headers=h).status_code == 502

    monkeypatch.setattr(engine, "_samples", real)
    again = client.post(f"/v1/stars/{star['id']}/float", headers=h).json()["star"]
    assert again["state"] == "floated" and again["analysis_failed"] is False


def test_writing_is_encrypted_at_rest(client):
    h = sign_in(client)
    star = float_star(client, h)
    with client.app.state.sessions() as db:
        from youniya_api.models import Star

        row = db.get(Star, star["id"])
        assert "무서웠다" not in row.body_enc and "걔 소식" not in row.title_enc
        assert "무서웠다" not in (row.analysis_enc or "")


def test_search_rewrite_and_draft(client):
    h = sign_in(client)
    first = float_star(client, h, body=CALM_BODY, title="느리게 흘러간 하루", mood="calm")
    float_star(client, h)
    found = client.get("/v1/stars", params={"q": "창밖"}, headers=h).json()["items"]
    assert [s["id"] for s in found] == [first["id"]] and "body" not in found[0]

    r = client.post("/v1/stars", json={"mood": "calm", "title": "느리게 흘러간 하루", "body": DEEP_BODY,
                                       "mode": "float", "rewrite_of": first["id"]}, headers=h).json()
    assert r["compare"]["previous_starlight"] == first["starlight"]

    client.put("/v1/drafts/current", json={"mood": "anger", "title": "쓰던 글", "body": "아직"}, headers=h)
    assert client.get("/v1/drafts/current", headers=h).json()["title"] == "쓰던 글"
    float_star(client, h)  # publishing clears the draft
    assert client.get("/v1/drafts/current", headers=h).json() is None


def test_trend_and_growth(client):
    h = sign_in(client)
    for _ in range(3):
        float_star(client, h)
    trend = client.get("/v1/starlight/trend", headers=h).json()
    assert len(trend["recent"]) == 3 and trend["enough"] is True
    growth = client.get("/v1/growth", headers=h).json()
    # 기획서 5.1: below 12 stars there is no stage yet, whatever the depth.
    assert growth["stage"] == 0 and growth["stage_name"] is None and growth["deep"] == 3
    assert growth["next"] == {"stage": 1, "stage_name": "첫 별들", "needs": {"stars": [3, 12]}}
    assert growth["milestones"][0]["key"] == "first_star"

    for i in range(9):  # kept stars count toward the 12 too
        r = client.post("/v1/stars", json={"mood": "calm", "title": f"간직 {i}", "body": "조용히 간직하는 글",
                                           "mode": "keep"}, headers=h)
        assert r.status_code == 201, r.text
    growth = client.get("/v1/growth", headers=h).json()
    assert growth["stage"] == 1 and growth["stage_name"] == "첫 별들"
    assert growth["next"]["needs"] == {"deep": [3, 6]}


def test_growth_stages_go_in_order():
    from youniya_api.rules import growth_stage

    assert growth_stage(10, 6, 0, 1) == 0  # deep enough for 2, but not 12 stars yet
    assert growth_stage(11, 30, 950, 4) == 0
    assert growth_stage(12, 0, 0, 1) == 1
    assert growth_stage(12, 6, 0, 1) == 2
    assert growth_stage(40, 30, 950, 3) == 4


# --- telescope and coins -----------------------------------------------------

def test_telescope_is_gone_and_charges_nothing(client):
    """마음 망원경 was removed (20261110): every old path is 410, nothing is charged or used up."""
    h = sign_in(client)
    star = float_star(client, h)
    client.post("/v1/coins/purchases", json={"product_id": "coin_110", "transaction_id": "t1"}, headers=h)
    for method, path in (("GET", "/v1/telescope/offer"), ("POST", "/v1/telescope/reports"),
                         ("GET", "/v1/telescope/reports/x"),
                         ("POST", "/v1/telescope/reports/x/save")):
        r = client.request(method, path, json={"star_ids": [star["id"]]} if method == "POST" else None, headers=h)
        assert r.status_code == 410 and r.json()["error"]["code"] == "feature_removed", path
    # Older iOS builds load the list when they open: empty, not an error.
    assert client.get("/v1/telescope/reports", headers=h).json() == {"items": []}
    me = client.get("/v1/me", headers=h).json()
    assert me["coins"] == 110 and me["free_telescope"] == 0 and me["free_telescope_available"] is False
    assert "telescope" not in client.get(f"/v1/stars/{star['id']}", headers=h).json()
    assert [e["kind"] for e in client.get("/v1/coins/history", headers=h).json()["items"]] == ["purchase"]





def test_unverified_purchase_adds_nothing(make_app):
    client = TestClient(make_app(trust_purchases=False))
    h = sign_in(client)
    r = client.post("/v1/coins/purchases", json={"product_id": "coin_120", "transaction_id": "t"}, headers=h)
    assert r.status_code == 503 and client.get("/v1/coins", headers=h).json()["coins"] == 0


# --- nebulae -----------------------------------------------------------------

def test_nebula_story(client):
    h = sign_in(client)
    ids = [float_star(client, h)["id"] for _ in range(3)]
    assert client.post("/v1/nebulae", json={"name": "n", "star_ids": ids[:2]}, headers=h).status_code == 422
    n = client.post("/v1/nebulae", json={"name": "느린 저녁의 성운", "silhouette": "flower", "star_ids": ids},
                    headers=h).json()
    detail = client.get(f"/v1/nebulae/{n['id']}", headers=h).json()
    assert detail["star_count"] == 3 and detail["depth_level"] == 7.0

    story = client.get(f"/v1/nebulae/{n['id']}/story", headers=h).json()
    assert all(e["sentence"] in DEEP_BODY for e in story["entries"]) and story["star_count"] == 3
    # 서사 다듬기 is gone (20261108): no bridges or offer, and no polish endpoint.
    assert not {"bridges", "polished", "polish_cost", "polish_free"} & story.keys()
    assert client.post(f"/v1/nebulae/{n['id']}/story/polish", headers=h).status_code in (404, 405)


# --- plaza -------------------------------------------------------------------

def test_preview_is_exactly_what_is_shared(client):
    """19-1 / 71-1: the app previews with privacy-scan on the chosen sentence; both shares store that text."""
    h = sign_in(client)
    quote = "지훈이 형이랑 망원시장에서 만나고 jh@mail.com으로 사진을 보냈다."
    ids = [float_star(client, h, body=DEEP_BODY + " " + quote)["id"]] + [float_star(client, h)["id"] for _ in range(2)]
    preview = client.post("/v1/plaza/privacy-scan", json={"text": quote}, headers=h).json()
    assert preview["masked"] == "●●● 형이랑 ●●●에서 만나고 ●●●으로 사진을 보냈다."
    assert preview["counts"] == {"contacts": 1, "names": 1, "places": 1} and preview["total"] == 3

    star = client.put(f"/v1/stars/{ids[0]}/share", json={"quote": quote}, headers=h).json()
    n = client.post("/v1/nebulae", json={"name": "성운", "star_ids": ids}, headers=h).json()
    nebula = client.put(f"/v1/nebulae/{n['id']}/share", json={"quote": quote}, headers=h).json()
    assert star["quote"] == nebula["quote"] == preview["masked"]


def test_star_share_is_masked_and_counts_stay_private(client):
    owner, other = sign_in(client, "owner"), sign_in(client, "other")
    body = DEEP_BODY + " 민지 씨한테 010-1234-5678로 연락했다."
    star = float_star(client, owner, body=body)
    scan = client.post("/v1/plaza/privacy-scan", json={"text": "민지 씨랑 강남역에서 만났다."}, headers=owner).json()
    assert scan["counts"] == {"contacts": 0, "names": 1, "places": 1}

    shared = client.put(f"/v1/stars/{star['id']}/share", json={"quote": "민지 씨한테 010-1234-5678로 연락했다."},
                        headers=owner).json()
    assert "민지" not in shared["quote"] and "1234" not in shared["quote"]
    assert client.put(f"/v1/stars/{star['id']}/share", json={"quote": "쓴 적 없는 문장"},
                      headers=owner).status_code == 422

    items = client.get("/v1/plaza/stars", headers=other).json()["items"]
    assert [i["id"] for i in items] == [shared["share_id"]]
    assert "resonances" not in items[0] and "starlight" not in items[0]
    assert client.get("/v1/plaza/stars", headers=owner).json()["items"] == []  # not my own

    client.put(f"/v1/plaza/star/{shared['share_id']}/resonance", json={}, headers=other)
    assert client.get("/v1/plaza/stars", headers=other).json()["items"][0]["resonated"] is True
    mine = client.get("/v1/me/shares", headers=owner).json()["stars"][0]
    assert mine["resonances"] == 1 and mine["title"] == "걔 소식을 들은 날"
    assert mine["starlight"] == star["starlight"] and mine["written_at"] == star["created_at"]
    assert client.put(f"/v1/plaza/star/{shared['share_id']}/resonance", headers=owner).status_code == 422


def test_starlight_lines_rules(client):
    owner, other, third = sign_in(client, "a"), sign_in(client, "b"), sign_in(client, "c")
    ids = [float_star(client, owner)["id"] for _ in range(3)]
    n = client.post("/v1/nebulae", json={"name": "비 온 뒤 고래자리", "star_ids": ids}, headers=owner).json()
    share = client.put(f"/v1/nebulae/{n['id']}/share", json={"receive_lines": True}, headers=owner).json()
    url = f"/v1/plaza/nebulae/{share['share_id']}/lines"

    assert client.post(url, json={"text": "가" * 61}, headers=other).json()["error"]["code"] == "too_long"
    assert client.post(url, json={"text": "그런 생각은 좀 유치한 것 같아요."}, headers=other).json()["error"]["code"] == "hurtful"
    line = client.post(url, json={"text": "고래자리 모양이 꼭 비 그친 하늘 같아요."}, headers=other)
    assert line.status_code == 201
    assert client.post(url, json={"text": "한 줄 더"}, headers=other).json()["error"]["code"] == "already_left"
    assert client.post(url, json={"text": "내 성운"}, headers=owner).json()["error"]["code"] == "own_share"

    # Reporting hides the line from the reporter at once.
    assert len(client.get(url, headers=third).json()["items"]) == 1
    client.post(f"/v1/plaza/lines/{line.json()['id']}/report", json={"reason": "hurtful"}, headers=third)
    assert client.get(url, headers=third).json()["items"] == []
    assert len(client.get(url, headers=other).json()["items"]) == 1

    # Lines fade after a day.
    with client.app.state.sessions() as db:
        from youniya_api.models import StarlightLine

        row = db.get(StarlightLine, line.json()["id"])
        row.created_at = datetime.now(timezone.utc) - timedelta(hours=25)
        db.commit()
    assert client.get(url, headers=other).json()["items"] == []

    client.put(f"/v1/nebulae/{n['id']}/share", json={"receive_lines": False}, headers=owner)
    assert client.post(url, json={"text": "닫힘"}, headers=third).status_code == 403


def test_withdraw_all_and_delete_account(client):
    h, other = sign_in(client, "me"), sign_in(client, "you")
    star = float_star(client, h)
    client.put(f"/v1/stars/{star['id']}/share", json={"quote": "그게 무서웠다."}, headers=h)
    assert client.delete("/v1/me/shares", headers=h).json()["withdrawn_stars"] == 1
    assert client.get("/v1/plaza/stars", headers=other).json()["items"] == []

    export = client.get("/v1/me/export", headers=h)
    assert export.status_code == 200 and "걔 소식을 들은 날" in export.text

    assert client.delete("/v1/me", headers=h).status_code == 204
    assert client.get("/v1/me", headers=h).status_code == 401
    with client.app.state.sessions() as db:
        from youniya_api.models import Star

        assert db.get(Star, star["id"]) is None


def test_settings_and_inquiry(client):
    h = sign_in(client)
    assert client.patch("/v1/me/settings", json={"sky": "ocean", "haptics": False}, headers=h).json()["sky"] == "ocean"
    # 기획서 13장: the other skies are for 별지기 멤버십.
    r = client.patch("/v1/me/settings", json={"sky": "aurora"}, headers=h)
    assert r.status_code == 403 and r.json()["error"]["code"] == "member_only"
    assert client.patch("/v1/me/settings", json={"sky": "nope"}, headers=h).status_code == 422
    r = client.post("/v1/inquiries", json={"kind": "payment", "email": "a@b.co", "body": "결제가 안 돼요"}, headers=h)
    assert r.status_code == 201
    assert client.post("/v1/inquiries", json={"kind": "payment", "email": "x", "body": "b"}, headers=h).status_code == 422


def test_dev_login_only_when_enabled(make_app):
    assert TestClient(make_app()).post("/v1/auth/dev", json={"name": "a"}).status_code == 404
    client = TestClient(make_app(dev_login=True))
    first = client.post("/v1/auth/dev", json={"name": "zhkim"}).json()
    again = client.post("/v1/auth/dev", json={"name": "zhkim"}).json()
    assert first["user_id"] == again["user_id"] and first["needs_consent"] is True


def test_me_has_joined_at(client):
    h = sign_in(client)
    me = client.get("/v1/me", headers=h).json()
    assert me["provider"] == "apple" and me["joined_at"].startswith("20") and "email" not in me
