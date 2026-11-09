"""Export and account deletion with the 20261109 data: links, 별빛 풀이, 망원경, 별자리 이야기, 별빛 한 줄."""

from sqlalchemy import func, select

from youniya_api.models import StarLine, StarLink, TelescopeReport

from .conftest import DEEP_BODY, float_star, sign_in

QUOTE = DEEP_BODY.split(". ")[0] + "."


def test_export_has_the_new_parts(client):
    h = sign_in(client)
    lit = float_star(client, h, title="빛난 별")
    plain = client.post("/v1/stars", json={"moods": ["calm", "sorrow"], "title": "조용한 별", "body": "첫 문장이에요. 둘째.",
                                           "mode": "unlit", "link_to": [lit["id"]]}, headers=h).json()["star"]
    client.post("/v1/telescope/reports", json={"star_ids": [lit["id"]]}, headers=h)
    text = client.get("/v1/me/export", headers=h).text
    assert "별의 깊이:" in text and "별빛 풀이:" in text and "마음 망원경:" in text
    assert "이어진 별: 조용한 별" in text and "이어진 별: 빛난 별" in text
    assert "평온 · 슬픔 · 별빛 없는 별" in text
    assert "별자리 이야기" in text and "첫 문장이에요." in text
    pdf = client.get("/v1/me/export", params={"format": "pdf"}, headers=h)
    assert pdf.status_code == 200 and pdf.content[:4] == b"%PDF"
    assert plain["id"]


def test_deleting_the_account_takes_links_lines_and_reports(client):
    h, other = sign_in(client), sign_in(client, "other")
    a, b = float_star(client, h), float_star(client, h)
    client.post(f"/v1/stars/{a['id']}/links", json={"star_ids": [b["id"]]}, headers=h)
    client.post("/v1/telescope/reports", json={"star_ids": [a["id"]]}, headers=h)
    theirs = float_star(client, other)
    sid = client.put(f"/v1/stars/{theirs['id']}/share", json={"quote": QUOTE}, headers=other).json()["share_id"]
    client.post(f"/v1/plaza/stars/{sid}/lines", json={"chip": "thanks"}, headers=h)
    assert client.delete("/v1/me", headers=h).status_code in (200, 204)
    with client.app.state.sessions() as db:
        assert db.scalar(select(func.count()).select_from(StarLink)) == 0
        assert db.scalar(select(func.count()).select_from(TelescopeReport)) == 0
        assert db.scalar(select(func.count()).select_from(StarLine)) == 0  # the line I left on their star
    assert client.get(f"/v1/stars/{theirs['id']}/lines", headers=other).json()["count"] == 0
