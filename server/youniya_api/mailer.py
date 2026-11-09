"""Email through Resend's HTTP API (A-07 문의 답장). Only operators' replies go out this way."""

import logging

import httpx

log = logging.getLogger(__name__)


class MailError(RuntimeError):
    pass


def send(api_key: str, sender: str, to: str, subject: str, text: str) -> str:
    """Returns Resend's message id; raises MailError when it refuses or cannot be reached."""
    try:
        r = httpx.post("https://api.resend.com/emails", timeout=15.0,
                       headers={"Authorization": f"Bearer {api_key}"},
                       json={"from": sender, "to": [to], "subject": subject, "text": text})
    except httpx.HTTPError as e:
        raise MailError(type(e).__name__) from e
    if r.status_code >= 400:
        log.warning("resend refused: %s", r.status_code)
        raise MailError(str(r.status_code))
    return r.json().get("id", "")
