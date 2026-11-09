"""16장 월별 별자리 (20261109)."""

from datetime import datetime, timedelta, timezone

from youniya_api.models import Star, User
from youniya_api.routers.constellations import TEMPLATES
from youniya_api.views import KST

from .conftest import DEEP_BODY, float_star, sign_in


def _this_month():
    return datetime.now(KST).strftime("%Y-%m")


def test_templates_are_whole():
    assert sorted(TEMPLATES) == list(range(1, 13))
    for t in TEMPLATES.values():
        assert all(0 <= x <= 1 and 0 <= y <= 1 for x, y in t["slots"])
        assert all(0 <= a < len(t["slots"]) and 0 <= b < len(t["slots"]) for a, b in t["lines"])


def test_stars_fill_the_month_in_order(client):
    h = sign_in(client)
    month = _this_month()
    t = TEMPLATES[int(month[5:])]
    empty = client.get(f"/v1/constellations/{month}", headers=h).json()
    assert empty["filled"] == 0 and all(s["star"] is None for s in empty["slots"]) and empty["lines"] == t["lines"]
    lit = float_star(client, h)
    plain = [client.post("/v1/stars", json={"mood": "calm", "body": f"별빛 없는 글 {i}.", "mode": "unlit"},
                         headers=h).json()["star"] for i in range(len(t["slots"]))]
    c = client.get(f"/v1/constellations/{month}", headers=h).json()
    assert c["key"] == t["key"] and c["name"] == t["name"] and c["total"] == len(t["slots"])
    assert c["slots"][0]["star"]["id"] == lit["id"] and c["slots"][0]["star"]["has_starlight"] is True
    assert c["slots"][1]["star"]["id"] == plain[0]["id"] and c["slots"][1]["star"]["starlight"] is None
    assert [s["id"] for s in c["extra"]] == [plain[-1]["id"]]
    assert c["complete"] is True and c["lit"] == 1 and c["unlit"] == len(plain) and c["deep"] == 1
    assert c["slots"][0]["x"] == t["slots"][0][0]

    story = client.get(f"/v1/constellations/{month}/story", headers=h).json()
    assert story["entries"][0]["sentence"] in DEEP_BODY and story["entries"][1]["sentence"] == "별빛 없는 글 0."
    listed = client.get("/v1/constellations", headers=h).json()["items"]
    assert listed[0]["month"] == month and listed[0]["complete"] is True


def test_months_outside_the_account_are_closed(client):
    h = sign_in(client)
    now = datetime.now(KST)
    nxt = (now.replace(day=28) + timedelta(days=5)).strftime("%Y-%m")
    assert client.get(f"/v1/constellations/{nxt}", headers=h).status_code == 404
    assert client.get("/v1/constellations/2000-01", headers=h).status_code == 404
    assert client.get("/v1/constellations/2026-13", headers=h).status_code == 422
    # Joined a while ago: past months are open, empty.
    with client.app.state.sessions() as db:
        u = db.query(User).one()
        u.created_at = datetime.now(timezone.utc) - timedelta(days=70)
        db.commit()
    months = client.get("/v1/constellations", headers=h).json()["items"]
    assert len(months) >= 3 and months[-1]["filled"] == 0
    past = client.get(f"/v1/constellations/{months[-1]['month']}", headers=h).json()
    assert past["filled"] == 0 and past["extra"] == []
