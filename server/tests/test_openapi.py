from .dump_openapi import PATH, render


def test_checked_in_spec_matches_the_code():
    assert PATH.read_text() == render(), "openapi.json is stale: run `.venv/bin/python -m tests.dump_openapi`"
