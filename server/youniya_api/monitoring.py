"""Error reports to Sentry. Writing never leaves the server: no request bodies, query strings,
headers, local variables or exception messages (they can quote what failed to parse) are sent.
What is sent: the exception type, the stack, the route and the release."""

import os

import sentry_sdk
from sentry_sdk.integrations.logging import LoggingIntegration

KEEP_HEADERS = {"user-agent", "x-app-version"}


def scrub(event: dict, _hint: dict | None = None) -> dict:
    request = event.get("request") or {}
    for key in ("data", "query_string", "cookies", "env"):
        request.pop(key, None)
    if "headers" in request:
        request["headers"] = {k: v for k, v in request["headers"].items() if k.lower() in KEEP_HEADERS}
    for exc in (event.get("exception") or {}).get("values", []):
        exc.pop("value", None)
        for frame in (exc.get("stacktrace") or {}).get("frames", []):
            frame.pop("vars", None)
    event.pop("extra", None)
    event.pop("user", None)
    if "logentry" in event:  # a logged error: keep the format, not the arguments
        event["logentry"].pop("params", None)
        event["logentry"].pop("formatted", None)
    event.pop("breadcrumbs", None)
    return event


def init_sentry(dsn: str | None, environment: str) -> bool:
    if not dsn:
        return False
    sentry_sdk.init(
        dsn=dsn,
        environment=environment,
        release=os.getenv("VERCEL_GIT_COMMIT_SHA") or None,
        send_default_pii=False,
        include_local_variables=False,
        max_request_body_size="never",
        traces_sample_rate=0,
        before_send=scrub,
        # Errors logged with log.error/exception become events; warnings stay in the host's logs.
        integrations=[LoggingIntegration(event_level="ERROR")],
    )
    return True
