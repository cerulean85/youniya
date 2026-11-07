"""Gemini REST call returning a JSON object (same call as Protoss psy_punch.engine)."""

import json
from collections.abc import Callable

import httpx

# Called with (model, usageMetadata) after every answer: tools/measure_ai_cost.py listens here.
usage_listeners: list[Callable[[str, dict], None]] = []


def generate_json(api_key: str, model: str, prompt: str, temperature: float = 0.0,
                  thinking: str | None = None, timeout: float = 60.0) -> dict:
    """`thinking` is the Gemini 3 thinking level ("low", "high"); None leaves the model's default."""
    config: dict = {"temperature": temperature, "responseMimeType": "application/json"}
    if thinking:
        config["thinkingConfig"] = {"thinkingLevel": thinking}
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    payload = {"contents": [{"parts": [{"text": prompt}]}], "generationConfig": config}
    with httpx.Client(timeout=timeout) as client:
        resp = client.post(url, json=payload, headers={"x-goog-api-key": api_key})
        resp.raise_for_status()
        data = resp.json()
        for listener in usage_listeners:
            listener(model, data.get("usageMetadata", {}))
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    out = json.loads(text)
    if not isinstance(out, dict):
        raise ValueError("model returned JSON that is not an object")
    return out
