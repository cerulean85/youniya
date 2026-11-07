import base64
import os
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
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
    # 2.5 is closed to new keys (404); these are the replacements Google lists (checked 20261107).
    prism_model: str = field(default_factory=lambda: os.getenv("PRISM_MODEL", "gemini-3.8-flash"))
    telescope_model: str = field(default_factory=lambda: os.getenv("TELESCOPE_MODEL", "gemini-3.1-pro-preview"))
    prism_samples: int = field(default_factory=lambda: int(os.getenv("PRISM_SAMPLES", "3")))
    # Gemini 3 thinking level for scoring. "low" halves the wait (12 s → 6.6 s per call, 20261107).
    prism_thinking: str | None = field(default_factory=lambda: os.getenv("PRISM_THINKING", "low") or None)

    apple_client_ids: tuple[str, ...] = field(default_factory=lambda: _list("APPLE_CLIENT_IDS"))
    google_client_ids: tuple[str, ...] = field(default_factory=lambda: _list("GOOGLE_CLIENT_IDS"))

    # 40 새 버전이 필요해요 / 41 잠시 점검 중이에요
    min_app_version: str = field(default_factory=lambda: os.getenv("MIN_APP_VERSION", "1.0.0"))
    maintenance_start: datetime | None = field(default_factory=lambda: _time("MAINTENANCE_START"))
    maintenance_end: datetime | None = field(default_factory=lambda: _time("MAINTENANCE_END"))

    # StoreKit 2 verification (28 코인 충전). Without a bundle id, purchases are refused.
    apple_bundle_id: str | None = field(default_factory=lambda: os.getenv("APPLE_BUNDLE_ID") or None)
    # App Store Server API key (App Store Connect › Users and Access › Integrations › In-App Purchase).
    # Needed to answer CONSUMPTION_REQUEST refund notifications.
    appstore_issuer_id: str | None = field(default_factory=lambda: os.getenv("APPSTORE_ISSUER_ID") or None)
    appstore_key_id: str | None = field(default_factory=lambda: os.getenv("APPSTORE_KEY_ID") or None)
    appstore_private_key_path: str | None = field(default_factory=lambda: os.getenv("APPSTORE_PRIVATE_KEY_PATH") or None)
    # The same .p8 (whole PEM) as one base64 line, for hosts with no files to read (Vercel). Wins over the path.
    appstore_private_key_base64: str | None = field(
        default_factory=lambda: os.getenv("APPSTORE_PRIVATE_KEY_BASE64") or None)
    # APNs auth key (Certificates, IDs & Profiles › Keys, with Apple Push Notifications service).
    # A different key from the In-App Purchase one. Without it no remote notification is sent.
    apns_team_id: str | None = field(default_factory=lambda: os.getenv("APNS_TEAM_ID") or None)
    apns_key_id: str | None = field(default_factory=lambda: os.getenv("APNS_KEY_ID") or None)
    apns_private_key_base64: str | None = field(default_factory=lambda: os.getenv("APNS_PRIVATE_KEY_BASE64") or None)
    apns_private_key_path: str | None = field(default_factory=lambda: os.getenv("APNS_PRIVATE_KEY_PATH") or None)
    allow_sandbox_purchases: bool = field(default_factory=lambda: os.getenv("ALLOW_SANDBOX_PURCHASES", "1") == "1")
    # X-Admin-Token for /v1/admin. Without it the operator API does not exist.
    admin_token: str | None = field(default_factory=lambda: os.getenv("ADMIN_TOKEN") or None)
    # POST /v1/auth/dev signs in by name, without Apple or Google. Development only.
    dev_login: bool = field(default_factory=lambda: os.getenv("DEV_LOGIN") == "1")
    # Behind a proxy that sets X-Forwarded-For (Vercel sets VERCEL=1 itself). Per-IP limits use that address.
    trust_proxy: bool = field(default_factory=lambda: os.getenv("TRUST_PROXY", os.getenv("VERCEL", "")) == "1")
    # Sentry DSN for error reports (youniya_api/monitoring.py). Without it nothing is sent.
    sentry_dsn: str | None = field(default_factory=lambda: os.getenv("SENTRY_DSN") or None)
    sentry_environment: str = field(default_factory=lambda: os.getenv(
        "SENTRY_ENVIRONMENT", "production" if os.getenv("VERCEL") == "1" else "development"))
    # POST /v1/auth/invite: operator-made accounts sign in with login and password (App Review).
    invite_login: bool = field(default_factory=lambda: os.getenv("INVITE_LOGIN") == "1")
    # Accept purchases without store verification. Development only.
    trust_purchases: bool = field(default_factory=lambda: os.getenv("TRUST_PURCHASES") == "1")

    def appstore_private_key(self) -> str | None:
        """The .p8 PEM: from APPSTORE_PRIVATE_KEY_BASE64 if set, else read from APPSTORE_PRIVATE_KEY_PATH."""
        return _pem(self.appstore_private_key_base64, self.appstore_private_key_path)

    def apns_private_key(self) -> str | None:
        return _pem(self.apns_private_key_base64, self.apns_private_key_path)


def _pem(b64: str | None, path: str | None) -> str | None:
    if b64:
        return base64.b64decode("".join(b64.split()), validate=True).decode()
    if path:
        return Path(path).read_text()
    return None
