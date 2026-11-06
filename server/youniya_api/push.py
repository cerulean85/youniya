"""Remote notifications through APNs (token-based auth, HTTP/2).

What the server sends:
- 101 신고 결과: when an operator has looked at a reported 별빛 한 줄, every reporter hears the outcome.
- 새 기능·혜택 알림: operator announcements, only to users who opted in (11, 87).

87 별 만들기 알림 is not here: the app schedules it on the device as a local notification.
Writing and analyses never go into a notification."""

import logging
import time
from dataclasses import dataclass
from datetime import datetime, timezone

import httpx
import jwt
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from .models import DeviceToken
from .views import local

log = logging.getLogger(__name__)

HOSTS = {"production": "https://api.push.apple.com", "sandbox": "https://api.sandbox.push.apple.com"}
# APNs refuses a provider token older than an hour and throttles ones renewed more than every 20 minutes.
TOKEN_LIFETIME = 40 * 60


@dataclass
class Message:
    title: str
    body: str
    kind: str  # "report_result" | "announcement": the app routes on it


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
                   "kind": message.kind}
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


def _reason(r: httpx.Response) -> str:
    try:
        return r.json().get("reason", "")
    except ValueError:
        return ""


def notify(db: Session, client: ApnsClient | None, user_ids: list[str], message: Message) -> dict:
    """Sends to every device of these users and forgets dead tokens. Without a client nothing is sent."""
    counts = {"sent": 0, "gone": 0, "failed": 0, "devices": 0}
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
