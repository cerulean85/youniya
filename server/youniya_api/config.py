import os
from dataclasses import dataclass, field
from datetime import datetime
from zoneinfo import ZoneInfo


def _list(name: str) -> tuple[str, ...]:
    return tuple(v.strip() for v in os.getenv(name, "").split(",") if v.strip())


def _time(name: str) -> datetime | None:
    """ISO time; without an offset it is read as Korean time (41 shows KST)."""
    v = os.getenv(name)
    if not v:
        return None
    t = datetime.fromisoformat(v)
    return t if t.tzinfo else t.replace(tzinfo=ZoneInfo("Asia/Seoul"))


@dataclass(frozen=True)
class Settings:
    database_url: str = field(default_factory=lambda: os.getenv("DATABASE_URL", "sqlite:///./youniya.db"))
    jwt_secret: str = field(default_factory=lambda: os.getenv("JWT_SECRET", ""))
    # Fernet key for writing at rest (Protoss concept.md 3장). `Fernet.generate_key()`.
    data_key: str = field(default_factory=lambda: os.getenv("DATA_ENCRYPTION_KEY", ""))

    gemini_api_key: str | None = field(default_factory=lambda: os.getenv("GEMINI_API_KEY") or None)
    # Protoss model selection (20261027): fast model for scoring, stronger one for reports.
    prism_model: str = field(default_factory=lambda: os.getenv("PRISM_MODEL", "gemini-2.5-flash"))
    telescope_model: str = field(default_factory=lambda: os.getenv("TELESCOPE_MODEL", "gemini-2.5-pro"))
    prism_samples: int = field(default_factory=lambda: int(os.getenv("PRISM_SAMPLES", "3")))

    apple_client_ids: tuple[str, ...] = field(default_factory=lambda: _list("APPLE_CLIENT_IDS"))
    google_client_ids: tuple[str, ...] = field(default_factory=lambda: _list("GOOGLE_CLIENT_IDS"))

    # 40 새 버전이 필요해요 / 41 잠시 점검 중이에요
    min_app_version: str = field(default_factory=lambda: os.getenv("MIN_APP_VERSION", "1.0.0"))
    maintenance_start: datetime | None = field(default_factory=lambda: _time("MAINTENANCE_START"))
    maintenance_end: datetime | None = field(default_factory=lambda: _time("MAINTENANCE_END"))

    # StoreKit 2 verification (28 코인 충전). Without a bundle id, purchases are refused.
    apple_bundle_id: str | None = field(default_factory=lambda: os.getenv("APPLE_BUNDLE_ID") or None)
    allow_sandbox_purchases: bool = field(default_factory=lambda: os.getenv("ALLOW_SANDBOX_PURCHASES", "1") == "1")
    # POST /v1/auth/dev signs in by name, without Apple or Google. Development only.
    dev_login: bool = field(default_factory=lambda: os.getenv("DEV_LOGIN") == "1")
    # Accept purchases without store verification. Development only.
    trust_purchases: bool = field(default_factory=lambda: os.getenv("TRUST_PURCHASES") == "1")
