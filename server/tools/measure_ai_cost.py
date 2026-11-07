"""What one telescope report, story polish and prism scoring cost with the real model.

    GEMINI_API_KEY=… python tools/measure_ai_cost.py [--out result.json]

Records Gemini's usageMetadata for every call. Prices are the paid-tier Standard rates on
https://ai.google.dev/gemini-api/docs/pricing (read 2026-11-07); thinking tokens are billed as output.
About 30 calls: 9 flash, the rest 3.1 Pro."""

import argparse
import json
import statistics
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api import llm  # noqa: E402
from youniya_api.config import Settings  # noqa: E402
from youniya_api.prism import PrismEngine  # noqa: E402
from youniya_api.prism.engine import split_sentences  # noqa: E402
from youniya_api.telescope import StarText, build_report, story_bridges  # noqa: E402

from seed_texts import PLAZA, REVIEW_FLOATED  # noqa: E402

# USD per 1M tokens: (input, output incl. thinking). Flash rates hold through 2026-12-31 (doubled from 2027).
PRICES = {"gemini-3.8-flash": (0.75, 3.75), "gemini-3.1-pro-preview": (2.00, 12.00)}
PRICES_2027 = {"gemini-3.8-flash": (1.50, 7.50), "gemini-3.1-pro-preview": (2.00, 12.00)}
KRW_PER_USD = 1500  # round, a little above the 2026 rates seen (about 1,460–1,480)


def cost(model: str, u: dict, prices=PRICES) -> float:
    pin, pout = prices[model]
    out = u.get("candidatesTokenCount", 0) + u.get("thoughtsTokenCount", 0)
    return (u.get("promptTokenCount", 0) * pin + out * pout) / 1e6


def star_of(length: int, offset: int) -> tuple[str, str]:
    """Distinct seed writing joined until the body is at least `length` characters."""
    bodies = [b for _, _, b in REVIEW_FLOATED[offset:]] + [b for _, _, b, _ in PLAZA]
    body = ""
    for b in bodies:
        if len(body) >= length:
            break
        body = (body + " " + b).strip()
    return REVIEW_FLOATED[offset][0], body


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path)
    ap.add_argument("--skip-prism", action="store_true")
    ap.add_argument("--timeout", type=float, default=240.0,
                    help="instead of the server's 90 s, to see what a slow call really costs and takes")
    a = ap.parse_args()
    import functools

    from youniya_api import telescope

    telescope.generate_json = functools.partial(llm.generate_json, timeout=a.timeout)
    s = Settings()
    if not s.gemini_api_key:
        sys.exit("GEMINI_API_KEY is not set")

    calls: list[dict] = []
    llm.usage_listeners.append(lambda model, u: calls.append({"model": model, **u}))

    def measured(label, fn):
        start, t = len(calls), time.time()
        try:
            result, error = fn(), None
        except Exception as e:  # noqa: BLE001 — a failed run is a result too
            result, error = None, type(e).__name__
        mine = calls[start:]
        row = {"label": label, "seconds": round(time.time() - t, 1), "calls": len(mine),
               "prompt": sum(c.get("promptTokenCount", 0) for c in mine),
               "candidates": sum(c.get("candidatesTokenCount", 0) for c in mine),
               "thoughts": sum(c.get("thoughtsTokenCount", 0) for c in mine),
               "total": sum(c.get("totalTokenCount", 0) for c in mine),
               "usd": sum(cost(c["model"], c) for c in mine),
               "usd_2027": sum(cost(c["model"], c, PRICES_2027) for c in mine), "error": error}
        rows.append(row)
        print(f"{label:34} {row['calls']} calls · {row['total']:>6} tok · ${row['usd']:.5f} · {row['seconds']}s"
              + (f" · FAILED {error}" if error else ""), flush=True)
        return result

    rows: list[dict] = []
    offline = PrismEngine(None, s.prism_model)
    stars = {"short": star_of(1000, 0), "normal": star_of(1800, 3), "long": star_of(3500, 6)}
    texts = {}
    for size, (title, body) in stars.items():
        texts[size] = StarText(size, title, body, "2026-11-07T00:00:00+00:00",
                               offline.evaluate(title, body, min_length=0).analysis)

    # 1. Prism, free on every floated star: 3 flash readings.
    prism = PrismEngine(s.gemini_api_key, s.prism_model, s.prism_samples, thinking=s.prism_thinking)
    for size, (title, body) in ([] if a.skip_prism else stars.items()):
        measured(f"prism · {size} ({len(body)}자)", lambda: prism.evaluate(title, body))

    # 2. Telescope, one star at a time, at the model's default thinking and at "low".
    samples = {}
    for thinking in (None, "low"):
        for size in ("short", "normal", "long") * (2 if thinking is None else 1):
            label = f"telescope · {size} · {thinking or 'default'}"
            out = measured(label, lambda: build_report([texts[size]], s.gemini_api_key, s.telescope_model, thinking))
            if out:
                samples.setdefault(label, {k: out[k] for k in ("star_name", "question")} |
                                   {"notes": [lens["note"] for lens in out["lenses"]]})

    # 3. Story polish for a 3-star and a 14-star nebula.
    sentences = [x for _, _, b in REVIEW_FLOATED for x in split_sentences(b)[:1]]
    for thinking in (None, "low"):
        for n in (3, 14) * (3 if thinking is None else 2):
            label = f"story · {n} sentences · {thinking or 'default'}"
            out = measured(label, lambda: story_bridges(sentences[:n], s.gemini_api_key, s.telescope_model, thinking))
            if out:
                samples.setdefault(label, out)

    def summary(prefix):
        group = [r for r in rows if r["label"].startswith(prefix)]
        return {"runs": len(group), "mean_usd": statistics.mean(r["usd"] for r in group),
                "max_usd": max(r["usd"] for r in group), "mean_usd_2027": statistics.mean(r["usd_2027"] for r in group),
                "mean_seconds": statistics.mean(r["seconds"] for r in group),
                "mean_thoughts": statistics.mean(r["thoughts"] for r in group)}

    groups = {k: summary(k) for k in ("prism", "telescope", "story") if any(r["label"].startswith(k) for r in rows)}
    for k in ("telescope", "story"):
        for t in ("default", "low"):
            group = [r for r in rows if r["label"].startswith(k) and r["label"].endswith(t)]
            groups[f"{k} · {t}"] = {"runs": len(group), "mean_usd": statistics.mean(r["usd"] for r in group),
                                    "max_usd": max(r["usd"] for r in group),
                                    "mean_thoughts": statistics.mean(r["thoughts"] for r in group),
                                    "mean_seconds": statistics.mean(r["seconds"] for r in group)}
    result = {"prices": PRICES, "krw_per_usd": KRW_PER_USD, "rows": rows, "groups": groups, "samples": samples}
    if a.out:
        a.out.write_text(json.dumps(result, ensure_ascii=False, indent=1))
    print(json.dumps(groups, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
