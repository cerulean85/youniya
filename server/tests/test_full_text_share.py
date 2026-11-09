"""별 나누기 with the whole writing (20261108): contacts masked, names and places as written."""

from .conftest import DEEP_BODY, float_star, sign_in

PRIVATE = " 민지 씨랑 강남역에서 만났고 010-1234-5678로 연락했다. 계좌는 110-123-456789, 주민번호는 900101-1234567이다."
QUOTE = DEEP_BODY.split(". ")[0] + "."


def test_contacts_mode_keeps_names_and_places():
    from youniya_api import privacy

    full = privacy.scan(PRIVATE, "contacts")
    assert "민지" in full["masked"] and "강남역" in full["masked"]
    assert "1234-5678" not in full["masked"] and "456789" not in full["masked"] and "1234567" not in full["masked"]
    assert full["counts"] == {"contacts": 3, "names": 0, "places": 0}
    assert "민지" not in privacy.scan(PRIVATE)["masked"]


def test_scan_endpoint_takes_the_mode(client):
    h = sign_in(client)
    r = client.post("/v1/plaza/privacy-scan", json={"text": PRIVATE, "mode": "contacts"}, headers=h).json()
    assert "강남역" in r["masked"] and r["counts"]["contacts"] == 3


def test_full_text_share_shows_the_writing_in_detail_only(client):
    h, other = sign_in(client), sign_in(client, "other")
    star = float_star(client, h, body=DEEP_BODY + PRIVATE, title="민지 씨 010-9999-8888")
    r = client.put(f"/v1/stars/{star['id']}/share", json={"quote": QUOTE, "full_text": True}, headers=h).json()
    assert r["full_text"] is True and r["name"] == "민지 씨 ●●●"

    item = client.get("/v1/plaza/stars", headers=other).json()["items"][0]
    assert item["quote"] == QUOTE and item["full_text"] is True
    assert "body_masked" not in item and "title_masked" not in item
    detail = client.get(f"/v1/plaza/stars/{item['id']}", headers=other).json()
    assert detail["title_masked"] == "민지 씨 ●●●"
    assert "민지 씨랑 강남역에서" in detail["body_masked"] and "5678" not in detail["body_masked"]
    assert detail["body_masked"].startswith(DEEP_BODY[:20])


def test_sentence_only_share_stays_as_before(client):
    h, other = sign_in(client), sign_in(client, "other")
    star = float_star(client, h, body=DEEP_BODY + PRIVATE)
    quote = PRIVATE.strip().split(". ")[0] + "."
    r = client.put(f"/v1/stars/{star['id']}/share", json={"quote": quote}, headers=h).json()
    assert r["full_text"] is False and "민지" not in r["quote"]
    item = client.get("/v1/plaza/stars", headers=other).json()["items"][0]
    detail = client.get(f"/v1/plaza/stars/{item['id']}", headers=other).json()
    assert detail["full_text"] is False and detail["body_masked"] is None and detail["title_masked"] is None


def test_edit_follows_a_full_text_share(client):
    """A star without starlight can still be rewritten in place; its share follows."""
    h, other = sign_in(client), sign_in(client, "other")
    star = client.post("/v1/stars", json={"mood": "insight", "title": "t", "body": DEEP_BODY, "mode": "unlit"},
                       headers=h).json()["star"]
    sid = client.put(f"/v1/stars/{star['id']}/share", json={"quote": QUOTE, "full_text": True},
                     headers=h).json()["share_id"]

    r = client.patch(f"/v1/stars/{star['id']}", json={"title": "고친 제목", "body": DEEP_BODY + " 덧붙인 말."},
                     headers=h).json()
    assert r["quote_missing"] is False and r["share_removed"] is False
    d = client.get(f"/v1/plaza/stars/{sid}", headers=other).json()
    assert d["title_masked"] == "고친 제목" and d["body_masked"].endswith("덧붙인 말.") and d["quote"] == QUOTE

    # The 대표 문장 is gone from the writing: the share stays, the sentence is cleared until picked again.
    r = client.patch(f"/v1/stars/{star['id']}", json={"body": "완전히 새로 쓴 글이에요. 처음과는 다른 이야기예요."},
                     headers=h).json()
    assert r["quote_missing"] is True and r["star"]["shared"] is True
    # Off the plaza until another is picked (older builds cannot read a share without one).
    assert client.get(f"/v1/plaza/stars/{sid}", headers=other).status_code == 404
    assert client.get("/v1/plaza/stars", headers=other).json()["items"] == []
    assert client.get("/v1/me/shares", headers=h).json()["stars"][0]["quote_missing"] is True
    again = client.put(f"/v1/stars/{star['id']}/share", json={"quote": "처음과는 다른 이야기예요.", "full_text": True},
                       headers=h).json()
    assert again["share_id"] == sid and again["quote"] == "처음과는 다른 이야기예요."
    d = client.get(f"/v1/plaza/stars/{sid}", headers=other).json()
    assert d["quote"] == "처음과는 다른 이야기예요." and d["body_masked"].startswith("완전히")


def test_a_new_crisis_signal_takes_the_star_off_the_plaza(client):
    h, other = sign_in(client), sign_in(client, "other")
    star = float_star(client, h)
    client.put(f"/v1/stars/{star['id']}/share", json={"quote": QUOTE, "full_text": True}, headers=h)
    r = client.patch(f"/v1/stars/{star['id']}", json={"title": "그냥 사라지고 싶다"}, headers=h).json()
    assert r["share_removed"] is True and r["crisis"] is not None and r["star"]["shared"] is False
    assert client.get("/v1/plaza/stars", headers=other).json()["items"] == []


def test_dates_times_and_amounts_are_not_numbers_to_hide():
    from youniya_api import privacy

    text = "2026-11-08 저녁 7시 30분, 3만 5천 원을 냈다. 12 34 56번 버스. 카드 1234-5678-9012-3456."
    masked = privacy.scan(text, "contacts")["masked"]
    assert "2026-11-08" in masked and "12 34 56" in masked and "9012" not in masked
