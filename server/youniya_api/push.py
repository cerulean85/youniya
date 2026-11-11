"""Remote notifications: APNs (iOS; token-based auth, HTTP/2) and FCM HTTP v1 (Android).

What the server sends:
- 101 신고 결과: when an operator has looked at a reported 별빛 한 줄, every reporter hears the outcome.
- 새 기능·혜택 알림: operator announcements, only to users who opted in (11, 87).

87 별 만들기 알림 is not here: the app schedules it on the device as a local notification.
Writing and analyses never go into a notification."""

import json
import logging
import time
from dataclasses import dataclass
from datetime import datetime, timezone

import httpx
import jwt
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from .google_api import FCM_SCOPE, ServiceAccount
from .models import DeviceToken, UserNotification
from .views import local

log = logging.getLogger(__name__)

HOSTS = {"production": "https://api.push.apple.com", "sandbox": "https://api.sandbox.push.apple.com"}
# APNs refuses a provider token older than an hour and throttles ones renewed more than every 20 minutes.
TOKEN_LIFETIME = 40 * 60


@dataclass
class Message:
    title: str
    body: str
    kind: str  # "report_result" | "announcement" | "notice" | "consent_result": the app routes on it
    # What a tap opens, e.g. {"screen": "star", "star_id": …}; also in the stored notification.
    target: dict | None = None


class ApnsClient:
    def __init__(self, team_id: str, key_id: str, private_key_pem: str, topic: str):
        self.team_id, self.key_id, self.key, self.topic = team_id, key_id, private_key_pem, topic
        self._token: tuple[str, float] | None = None
        self._http = httpx.Client(http2=True, timeout=10.0)

    def _provider_token(self) -> str:
        now = time.time()
        if self._token is None or now - self._token[1] > TOKEN_LIFETIME:
            token = jwt.encode({"iss": self.team_id, "iat": int(now)}, self.key, algorithm="ES256",
                               headers={"kid": self.key_id})
            self._token = (token, now)
        return self._token[0]

    def send(self, device_token: str, environment: str, message: Message) -> str:
        """Returns "sent", "gone" (the token is dead: forget it) or "failed"."""
        return self.send_detail(device_token, environment, message)[0]

    def send_detail(self, device_token: str, environment: str, message: Message) -> tuple[str, int | None, str]:
        """(result, APNs status, APNs reason), for the operator's test push."""
        payload = {"aps": {"alert": {"title": message.title, "body": message.body}, "sound": "default"},
                   "kind": message.kind, **({"target": message.target} if message.target else {})}
        try:
            r = self._http.post(f"{HOSTS[environment]}/3/device/{device_token}", json=payload, headers={
                "authorization": f"bearer {self._provider_token()}",
                "apns-topic": self.topic, "apns-push-type": "alert", "apns-priority": "10",
            })
        except httpx.HTTPError as e:
            log.warning("apns request failed: %s", e)
            return "failed", None, type(e).__name__
        if r.status_code == 200:
            return "sent", 200, ""
        reason = _reason(r)
        if r.status_code == 410 or reason in ("BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"):
            return "gone", r.status_code, reason
        log.warning("apns %s %s", r.status_code, reason)
        return "failed", r.status_code, reason


class FcmClient:
    """FCM HTTP v1 (Firebase project youniya). Android devices are kept with environment "fcm"."""

    def __init__(self, service_account: dict, http: httpx.Client | None = None):
        self.account = ServiceAccount(service_account, FCM_SCOPE, http)
        self.project = service_account["project_id"]
        self._http = self.account.http

    def send(self, device_token: str, environment: str, message: Message) -> str:
        return self.send_detail(device_token, environment, message)[0]

    def send_detail(self, device_token: str, environment: str, message: Message) -> tuple[str, int | None, str]:
        # data values must be strings; the app reads `kind` and `target` (JSON) as on iOS.
        data = {"kind": message.kind, **({"target": json.dumps(message.target, ensure_ascii=False)} if message.target else {})}
        payload = {"message": {"token": device_token, "notification": {"title": message.title, "body": message.body},
                               "data": data, "android": {"priority": "high", "notification": {"sound": "default"}}}}
        try:
            r = self._http.post(f"https://fcm.googleapis.com/v1/projects/{self.project}/messages:send",
                                json=payload, headers=self.account.headers())
        except httpx.HTTPError as e:
            log.warning("fcm request failed: %s", e)
            return "failed", None, type(e).__name__
        if r.status_code == 200:
            return "sent", 200, ""
        reason, message_text = _fcm_error(r)
        # UNREGISTERED: the app was uninstalled or the token rotated. A 400 about the token: never valid.
        if reason == "UNREGISTERED" or r.status_code == 404 or (
                r.status_code == 400 and "registration token" in message_text.lower()):
            return "gone", r.status_code, reason or "UNREGISTERED"
        log.warning("fcm %s %s %s", r.status_code, reason, message_text[:200])
        return "failed", r.status_code, reason


def _fcm_error(r: httpx.Response) -> tuple[str, str]:
    try:
        err = r.json().get("error", {})
    except ValueError:
        return "", ""
    codes = [d.get("errorCode") for d in err.get("details", []) if d.get("errorCode")]
    return (codes[0] if codes else err.get("status", "")), err.get("message", "")


class Push:
    """Sends through APNs or FCM by the device's environment ("fcm": Android). Either may be missing:
    a device whose service is not configured counts as "failed" and is kept."""

    def __init__(self, apns: ApnsClient | None = None, fcm: FcmClient | None = None):
        self.apns, self.fcm = apns, fcm

    def send(self, device_token: str, environment: str, message: Message) -> str:
        return self.send_detail(device_token, environment, message)[0]

    def send_detail(self, device_token: str, environment: str, message: Message) -> tuple[str, int | None, str]:
        client = self.fcm if environment == "fcm" else self.apns
        if client is None:
            return "failed", None, "not_configured"
        return client.send_detail(device_token, environment, message)


def _reason(r: httpx.Response) -> str:
    try:
        return r.json().get("reason", "")
    except ValueError:
        return ""


def notify(db: Session, client: "Push | ApnsClient | None", user_ids: list[str], message: Message) -> dict:
    """Keeps it in each user's 알림함 (GET /v1/me/notifications), then sends to every device of these users
    and forgets dead tokens. Without a client nothing is sent, but it is still kept."""
    counts = {"sent": 0, "gone": 0, "failed": 0, "devices": 0}
    user_ids = list(dict.fromkeys(u for u in user_ids if u))
    if user_ids:
        for u in user_ids:
            db.add(UserNotification(user_id=u, kind=message.kind, title=message.title, body=message.body,
                                    target=message.target))
        db.commit()
    if client is None or not user_ids:
        return counts
    devices = db.scalars(select(DeviceToken).where(DeviceToken.user_id.in_(user_ids))).all()
    counts["devices"] = len(devices)
    dead = []
    for d in devices:
        result = client.send(d.token, d.environment, message)
        counts[result] += 1
        if result == "gone":
            dead.append(d.token)
    if dead:
        db.execute(delete(DeviceToken).where(DeviceToken.token.in_(dead)))
        db.commit()
    return counts


def is_night_kst(at: datetime | None = None) -> bool:
    """정보통신망법 50조: advertising between 21:00 and 08:00 needs its own consent, which we do not ask for."""
    hour = local(at or datetime.now(timezone.utc)).hour
    return hour >= 21 or hour < 8
