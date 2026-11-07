"""Gemini REST call returning a JSON object (same call as Protoss psy_punch.engine)."""

import json
from collections.abc import Callable

import httpx

# Called with (model, usageMetadata) after every answer: tools/measure_ai_cost.py listens here.
usage_listeners: list[Callable[[str, dict], None]] = []


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


def generate_json(api_key: str, model: str, prompt: str, temperature: float = 0.0,
                  thinking: str | None = None, timeout: float = 60.0, retries: int = 0) -> dict:
    """`retries`: further tries after a timeout, a dropped connection, 429 or 5xx. A bad answer is not retried."""
    config: dict = {"temperature": temperature, "responseMimeType": "application/json"}
    if tc := thinking_config(model, thinking):
        config["thinkingConfig"] = tc
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    payload = {"contents": [{"parts": [{"text": prompt}]}], "generationConfig": config}
    for attempt in range(retries + 1):
        try:
            with httpx.Client(timeout=timeout) as client:
                resp = client.post(url, json=payload, headers={"x-goog-api-key": api_key})
                resp.raise_for_status()
                data = resp.json()
            break
        except Exception as e:
            if attempt == retries or not _retryable(e):
                raise
    for listener in usage_listeners:
        listener(model, data.get("usageMetadata", {}))
    out = json.loads(data["candidates"][0]["content"]["parts"][0]["text"])
    if not isinstance(out, dict):
        raise ValueError("model returned JSON that is not an object")
    return out
