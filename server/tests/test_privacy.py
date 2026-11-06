from youniya_api.privacy import is_hurtful, scan


def test_masks_contacts_names_and_places_with_particles():
    out = scan("민지 씨한테 010-1234-5678로 전화했고 a.b@mail.com으로 메일도 보냈다. 강남역에서 만났다.")
    assert out["counts"] == {"contacts": 2, "names": 1, "places": 1}
    for leaked in ("민지", "1234", "mail.com", "강남역"):
        assert leaked not in out["masked"]
    assert "에서 만났다" in out["masked"]


def test_leaves_plain_writing_alone():
    text = "오늘은 마음이 조금 느리게 흘렀어요. 2026년 11월 3일이었어요."
    assert scan(text) == {"masked": text, "counts": {"contacts": 0, "names": 0, "places": 0}, "total": 0}


def test_hurtful_lines():
    assert is_hurtful("그런 생각은 좀 유치한 것 같아요.")  # Figma 99
    assert not is_hurtful("고래자리 모양이 꼭 비 그친 하늘 같아요.")
