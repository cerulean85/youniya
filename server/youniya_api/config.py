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
    telescope_model: str = field(default_factory=lambda: os.getenv("TELESCOPE_MODEL", "gemini-3.8-flash"))
    prism_samples: int = field(default_factory=lambda: int(os.getenv("PRISM_SAMPLES", "1")))
    # Gemini 3 thinking level for scoring. "low" halves the wait (12 s → 6.6 s per call, 20261107).
    prism_thinking: str | None = field(default_factory=lambda: os.getenv("PRISM_THINKING", "low") or None)
    # The same for telescope reports ("off", "low", "high"; empty: the model's default).
    telescope_thinking: str | None = field(default_factory=lambda: os.getenv("TELESCOPE_THINKING", "low") or None)
    # 별 띄우기 free a Korean day; after that each costs STAR_FLOAT_COST coins.
    free_stars_per_day: int = field(default_factory=lambda: int(os.getenv("FREE_STARS_PER_DAY", "1")))

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
    # Sign in with Apple key (Certificates, IDs & Profiles › Keys, with Sign in with Apple; yet another .p8).
    # Revokes the Apple tokens when an account is deleted (5.1.1(v)). The team id falls back to APNS_TEAM_ID.
    apple_team_id: str | None = field(default_factory=lambda: os.getenv("APPLE_TEAM_ID") or os.getenv("APNS_TEAM_ID") or None)
    apple_siwa_key_id: str | None = field(default_factory=lambda: os.getenv("APPLE_SIWA_KEY_ID") or None)
    apple_siwa_private_key_base64: str | None = field(
        default_factory=lambda: os.getenv("APPLE_SIWA_PRIVATE_KEY_BASE64") or None)
    apple_siwa_private_key_path: str | None = field(default_factory=lambda: os.getenv("APPLE_SIWA_PRIVATE_KEY_PATH") or None)
    # Google Play (안드로이드 코인 충전): the app's package and a service account with access to it in Play Console
    # (사용자 및 권한 › 재무 데이터 보기, 주문 관리). Without both, Android purchases are refused (TRUST_PURCHASES
    # aside) and Play refunds are not checked. The key JSON as one base64 line, or a path.
    google_play_package: str | None = field(default_factory=lambda: os.getenv("GOOGLE_PLAY_PACKAGE") or None)
    google_play_service_account_base64: str | None = field(
        default_factory=lambda: os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_BASE64") or None)
    google_play_service_account_path: str | None = field(
        default_factory=lambda: os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_PATH") or None)
    # FCM (안드로이드 알림): a service account key of Firebase project youniya (프로젝트 설정 › 서비스 계정).
    fcm_service_account_base64: str | None = field(default_factory=lambda: os.getenv("FCM_SERVICE_ACCOUNT_BASE64") or None)
    fcm_service_account_path: str | None = field(default_factory=lambda: os.getenv("FCM_SERVICE_ACCOUNT_PATH") or None)
    # 안드로이드 Apple 로그인 (web flow in a Custom Tab): the Services ID (also in APPLE_CLIENT_IDS) and this
    # server's callback, registered as a Return URL of that Services ID. Unset: the flow is 404.
    apple_services_id: str | None = field(default_factory=lambda: os.getenv("APPLE_SERVICES_ID") or None)
    apple_handoff_redirect_uri: str | None = field(
        default_factory=lambda: os.getenv("APPLE_HANDOFF_REDIRECT_URI") or None)
    # Where the callback sends the one-time code: the Android app's deep link.
    apple_handoff_return: str = field(
        default_factory=lambda: os.getenv("APPLE_HANDOFF_RETURN", "youniya://auth/apple"))
    allow_sandbox_purchases: bool = field(default_factory=lambda: os.getenv("ALLOW_SANDBOX_PURCHASES", "1") == "1")
    # X-Admin-Token for /v1/admin. Without it the operator API does not exist.
    admin_token: str | None = field(default_factory=lambda: os.getenv("ADMIN_TOKEN") or None)
    # A-07 문의 답장 by email through Resend (https://resend.com). Without the key, replies are refused.
    resend_api_key: str | None = field(default_factory=lambda: os.getenv("RESEND_API_KEY") or None)
    mail_from: str = field(default_factory=lambda: os.getenv("MAIL_FROM", "YOUNIYA <support@youniya.dycdyp.com>"))
    # Accounts whose devices hear of urgent reports (18.3), comma separated user ids.
    operator_user_ids: tuple[str, ...] = field(default_factory=lambda: tuple(
        i.strip() for i in os.getenv("OPERATOR_USER_IDS", "").split(",") if i.strip()))
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
    # 별지기 멤버십 (v1.1). Off: every membership API is 404 and /v1/me says nothing of it.
    membership: bool = field(default_factory=lambda: os.getenv("MEMBERSHIP") == "1")
    # Vercel Cron sends "Authorization: Bearer <CRON_SECRET>". Unset: the /v1/cron routes are 404.
    cron_secret: str | None = field(default_factory=lambda: os.getenv("CRON_SECRET") or None)
    # Accept purchases without store verification. Development only.
    trust_purchases: bool = field(default_factory=lambda: os.getenv("TRUST_PURCHASES") == "1")
    # 토스페이먼츠 (web 코인 충전, API 개별 연동). Without the secret key the web can't buy coins.
    # test_sk_… in development, live_sk_… in production; never in a message or a commit.
    toss_secret_key: str | None = field(default_factory=lambda: os.getenv("TOSS_SECRET_KEY") or None)
    toss_client_key: str | None = field(default_factory=lambda: os.getenv("TOSS_CLIENT_KEY") or None)
    # With a test key only accounts made before this time may pay (routers/payments.can_pay); unset: nobody.
    # TOSS_TEST_OPEN=1 lets everyone (development).
    toss_test_accounts_before: datetime | None = field(default_factory=lambda: _time("TOSS_TEST_ACCOUNTS_BEFORE"))
    # And these user ids, added one by one (comma separated).
    toss_test_user_ids: tuple[str, ...] = field(default_factory=lambda: _list("TOSS_TEST_USER_IDS"))
    toss_test_open: bool = field(default_factory=lambda: os.getenv("TOSS_TEST_OPEN") == "1")

    def appstore_private_key(self) -> str | None:
        """The .p8 PEM: from APPSTORE_PRIVATE_KEY_BASE64 if set, else read from APPSTORE_PRIVATE_KEY_PATH."""
        return _pem(self.appstore_private_key_base64, self.appstore_private_key_path)

    def apns_private_key(self) -> str | None:
        return _pem(self.apns_private_key_base64, self.apns_private_key_path)

    def siwa_private_key(self) -> str | None:
        return _pem(self.apple_siwa_private_key_base64, self.apple_siwa_private_key_path)


def _pem(b64: str | None, path: str | None) -> str | None:
    if b64:
        return base64.b64decode("".join(b64.split()), validate=True).decode()
    if path:
        return Path(path).read_text()
    return None
