import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient

from youniya_api.config import Settings
from youniya_api.main import create_app

from .migrate import upgrade

# 1,000+ characters that reach a new understanding (Protoss ex_955, made longer).
DEEP_BODY = (
    "걔 소식 듣고 축하한다고 말하면서 속이 쓰렸다. 정리해 보면 나는 걔가 나랑 비슷한 자리에 있어야 안심이 됐던 것 같다. "
    "걔가 앞서가니까 내가 지금 어디에 서 있는지가 갑자기 보였고, 그게 무서웠다. "
    "질투는 걔를 향한 게 아니라 그 무서움을 덮는 방법이었다. "
    "내가 원하는 건 걔가 넘어지는 게 아니라, 걔 없이도 내 위치를 납득할 수 있는 기준이다. "
) * 8
CALM_BODY = (
    "오늘은 마음이 조금 느리게 흘렀어요. 해야 할 일은 많았는데 자꾸만 창밖을 보게 됐어요. "
    "기다리는 일이 이렇게 오래 걸릴 줄 몰랐어요. 그래도 그 느림이 싫지만은 않았어요. "
    "어쩌면 나는 쉬고 싶었는지도 몰라요. 괜찮다는 말을 스스로에게 해 주고 싶었어요. "
) * 8


class FakeVerifier:
    """The ID token is the account's `sub`, or "bad" for a rejected token."""

    def verify(self, provider, id_token):
        import jwt

        if id_token == "bad":
            raise jwt.InvalidTokenError("bad")
        return id_token


@pytest.fixture
def make_app(tmp_path):
    def build(**overrides):
        url = f"sqlite:///{tmp_path}/test.db"
        upgrade(url)  # the schema always comes from the migrations
        settings = Settings(**{
            "database_url": url,
            "jwt_secret": "test-secret-at-least-32-bytes-long!!",
            "data_key": Fernet.generate_key().decode(),
            "gemini_api_key": None,
            "trust_purchases": True,
            # Most tests float many stars; the one-a-day rule has its own test (test_free_uses.py).
            "free_stars_per_day": 10**6,
            **overrides,
        })
        app = create_app(settings)
        app.state.verifier = FakeVerifier()
        return app

    return build


@pytest.fixture
def app(make_app):
    return make_app()


@pytest.fixture
def client(app):
    return TestClient(app)


def sign_in(client, sub="user-1", consent=True) -> dict:
    tokens = client.post("/v1/auth/apple", json={"id_token": sub}).json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    if consent:
        r = client.post("/v1/me/consent", json={"terms": True, "privacy": True, "sensitive": True}, headers=headers)
        assert r.status_code == 200
    return headers


def float_star(client, headers, body=DEEP_BODY, title="걔 소식을 들은 날", mood="insight") -> dict:
    r = client.post("/v1/stars", json={"mood": mood, "title": title, "body": body, "mode": "float"}, headers=headers)
    assert r.status_code == 201, r.text
    return r.json()["star"]
