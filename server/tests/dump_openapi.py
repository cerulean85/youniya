"""Writes openapi.json from the current code: `.venv/bin/python -m tests.dump_openapi`."""

import json
from pathlib import Path

from cryptography.fernet import Fernet

from youniya_api.config import Settings
from youniya_api.main import create_app

PATH = Path(__file__).parent.parent / "openapi.json"


def spec() -> dict:
    settings = Settings(database_url="sqlite://", jwt_secret="x" * 40, data_key=Fernet.generate_key().decode())
    return create_app(settings).openapi()


def render() -> str:
    return json.dumps(spec(), ensure_ascii=False, indent=2) + "\n"


if __name__ == "__main__":
    PATH.write_text(render())
    print(f"wrote {PATH}")
