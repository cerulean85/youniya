"""Gemini REST call returning a JSON object (same call as Protoss psy_punch.engine)."""

import json

import httpx


def generate_json(api_key: str, model: str, prompt: str, temperature: float = 0.0) -> dict:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": temperature, "responseMimeType": "application/json"},
    }
    with httpx.Client(timeout=60.0) as client:
        resp = client.post(url, json=payload, headers={"x-goog-api-key": api_key})
        resp.raise_for_status()
        text = resp.json()["candidates"][0]["content"]["parts"][0]["text"]
    return json.loads(text)
