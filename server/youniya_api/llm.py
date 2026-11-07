"""Gemini REST call returning a JSON object (same call as Protoss psy_punch.engine).

Prompts are sent as a fixed part (rules and examples, the same for everyone) followed by the
user's part, so Gemini's implicit cache can match the shared prefix; with an explicit cache
(youniya_api/ai_cache.py) only the user's part is sent."""

import contextvars
import json
import logging
from collections.abc import Callable

import httpx

log = logging.getLogger(__name__)
BASE = "https://generativelanguage.googleapis.com/v1beta"

# Called with (model, usageMetadata) after every answer: tools/measure_ai_cost.py listens here.
usage_listeners: list[Callable[[str, dict], None]] = []
# (model, usageMetadata) of every call made while a request's cost is being metered (ai_cost.metered).
meter: contextvars.ContextVar[list | None] = contextvars.ContextVar("ai_meter", default=None)


def thinking_config(model: str, thinking: str | None) -> dict | None:
    """"low"/"high" as given. "off": no thinking at all, which Flash takes as a zero budget and
    Flash-Lite only as the "minimal" level (checked 20261107). None: the model's default."""
    if not thinking:
        return None
    if thinking == "off":
        return {"thinkingLevel": "minimal"} if "lite" in model else {"thinkingBudget": 0}
    return {"thinkingLevel": thinking}


def _retryable(e: Exception) -> bool:
    if isinstance(e, httpx.TimeoutException | httpx.TransportError):
        return True
    return isinstance(e, httpx.HTTPStatusError) and (e.response.status_code == 429 or e.response.status_code >= 500)


def _post(api_key: str, model: str, payload: dict, timeout: float, retries: int) -> dict:
    for attempt in range(retries + 1):
        try:
            with httpx.Client(timeout=timeout) as client:
                resp = client.post(f"{BASE}/models/{model}:generateContent", json=payload,
                                   headers={"x-goog-api-key": api_key})
                resp.raise_for_status()
                return resp.json()
        except Exception as e:
            if attempt == retries or not _retryable(e):
                raise
    raise AssertionError("unreachable")


def generate_json(api_key: str, model: str, prompt: str, temperature: float = 0.0,
                  thinking: str | None = None, timeout: float = 60.0, retries: int = 0,
                  prefix: str = "", cache: str | None = None) -> dict:
    """`prefix` is the fixed part, `prompt` the user's. `cache`: an explicit cache holding `prefix`;
    if Gemini refuses it (expired, gone), the call is made again with the prefix in full.
    `retries`: further tries after a timeout, a dropped connection, 429 or 5xx."""
    config: dict = {"temperature": temperature, "responseMimeType": "application/json"}
    if tc := thinking_config(model, thinking):
        config["thinkingConfig"] = tc
    full = {"contents": [{"role": "user", "parts": [{"text": prefix + prompt}]}], "generationConfig": config}
    data = None
    if cache:
        try:
            data = _post(api_key, model, {"contents": [{"role": "user", "parts": [{"text": prompt}]}],
                                          "cachedContent": cache, "generationConfig": config}, timeout, retries)
        except httpx.HTTPStatusError as e:
            if e.response.status_code not in (400, 403, 404):
                raise
            log.warning("explicit cache %s refused (%s): sending the prompt in full", cache, e.response.status_code)
    if data is None:
        data = _post(api_key, model, full, timeout, retries)
    usage = data.get("usageMetadata", {})
    for listener in usage_listeners:
        listener(model, usage)
    if (entries := meter.get()) is not None:
        entries.append((model, usage))
    out = json.loads(data["candidates"][0]["content"]["parts"][0]["text"])
    if not isinstance(out, dict):
        raise ValueError("model returned JSON that is not an object")
    return out
