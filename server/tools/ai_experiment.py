"""The 20261107 model experiment: cheaper prism, telescope and story polish without Pro.

    GEMINI_API_KEY=… python tools/ai_experiment.py OUT_DIR

Writes OUT_DIR/experiment.json (every call's tokens, cost, time and output) and the prism
quality checks as OUT_DIR/prism_<variant>.json (tools/eval_prism.py per variant)."""

import json
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api import llm  # noqa: E402
from youniya_api.prism import PrismEngine  # noqa: E402
from youniya_api.prism.engine import split_sentences  # noqa: E402
from youniya_api.telescope import MAX_BRIDGE_LENGTH, StarText, build_report, story_bridges  # noqa: E402

from measure_ai_cost import KRW_PER_USD, star_of  # noqa: E402
from seed_texts import REVIEW_FLOATED  # noqa: E402

# USD per 1M tokens (input, output incl. thinking), Standard paid tier, read 2026-11-07.
PRICES = {
    "gemini-3.8-flash": (0.75, 3.75),
    "gemini-3.5-flash-lite": (0.30, 2.50),
    "gemini-3.1-flash-lite": (0.25, 1.50),
    "gemini-3.1-pro-preview": (2.00, 12.00),
}
PRICES_2027 = PRICES | {"gemini-3.8-flash": (1.50, 7.50)}  # only Flash has a published change

FLASH = "gemini-3.8-flash"
PRISM_VARIANTS = {  # name: (model, readings, thinking)
    "A": (FLASH, 3, "low"),
    "B-low": (FLASH, 1, "low"),
    "B-off": (FLASH, 1, "off"),
    "C-3.5lite": ("gemini-3.5-flash-lite", 1, "off"),
    "C-3.1lite": ("gemini-3.1-flash-lite", 1, "off"),
}


def usd(model, u, prices=PRICES):
    pin, pout = prices[model]
    return (u.get("promptTokenCount", 0) * pin
            + (u.get("candidatesTokenCount", 0) + u.get("thoughtsTokenCount", 0)) * pout) / 1e6


def main() -> None:
    import os

    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    key = os.environ["GEMINI_API_KEY"]
    calls: list[dict] = []
    llm.usage_listeners.append(lambda m, u: calls.append({"model": m, **u}))
    rows: list[dict] = []

    def run(part, variant, case, fn):
        start, t = len(calls), time.time()
        try:
            result, error = fn(), None
        except Exception as e:  # noqa: BLE001
            result, error = None, type(e).__name__
        mine = calls[start:]
        row = {"part": part, "variant": variant, "case": case, "seconds": round(time.time() - t, 1),
               "calls": len(mine), "error": error,
               "prompt": sum(c.get("promptTokenCount", 0) for c in mine),
               "output": sum(c.get("candidatesTokenCount", 0) for c in mine),
               "thoughts": sum(c.get("thoughtsTokenCount", 0) for c in mine),
               "usd": sum(usd(c["model"], c) for c in mine),
               "usd_2027": sum(usd(c["model"], c, PRICES_2027) for c in mine),
               "result": result}
        rows.append(row)
        print(f"{part:9} {variant:10} {case:22} {row['calls']} calls · {row['prompt']}/{row['output']}/"
              f"{row['thoughts']} tok · {row['usd'] * KRW_PER_USD:6.2f}원 · {row['seconds']}s"
              + (f" · FAILED {error}" if error else ""), flush=True)
        return result

    stars = {"short": star_of(1000, 0), "normal": star_of(1800, 3), "long": star_of(3500, 6)}
    offline = PrismEngine(None, FLASH)
    texts = {k: StarText(k, t, b, "2026-11-07T00:00:00+00:00", offline.evaluate(t, b, min_length=0).analysis)
             for k, (t, b) in stars.items()}

    # 1. Prism cost per star, each variant on the same three stars.
    for name, (model, n, thinking) in PRISM_VARIANTS.items():
        engine = PrismEngine(key, model, n, thinking=thinking)
        for size, (title, body) in stars.items():
            r = run("prism", name, f"{size} {len(body)}자", lambda: engine.evaluate(title, body))
            if rows[-1]["result"] is not None:
                a = r.analysis or {}
                rows[-1]["result"] = {"status": r.status, "starlight": a.get("starlight"),
                                      "depth_level": a.get("depth_level"), "observation": a.get("observation")}

    # 2. Telescope on Flash, thinking low and off, twice per star.
    for thinking in ("low", "off"):
        for size in ("short", "normal", "long") * 2:
            r = run("telescope", f"flash-{thinking}", size,
                    lambda: build_report([texts[size]], key, FLASH, thinking))
            if r:
                rows[-1]["result"] = {"star_name": r["star_name"], "question": r["question"],
                                      "notes": [lens["note"] for lens in r["lenses"]], "evidence": r["evidence"]}

    # 3. Story polish with the new prompt, thinking low and off, twice per size.
    sentences = [split_sentences(b)[0] for _, _, b in REVIEW_FLOATED]
    for thinking in ("low", "off"):
        for n in (3, 14) * 2:
            run("story", f"flash-{thinking}", f"{n} sentences",
                lambda: story_bridges(sentences[:n], key, FLASH, thinking))
    (out_dir / "experiment.json").write_text(json.dumps(
        {"prices": PRICES, "prices_2027": PRICES_2027, "krw_per_usd": KRW_PER_USD, "max_bridge": MAX_BRIDGE_LENGTH,
         "stars": {k: len(b) for k, (_, b) in stars.items()}, "sentences": sentences, "rows": rows},
        ensure_ascii=False, indent=1))

    # 4. Prism quality: the scaled-down Protoss check for each variant.
    for name, (model, n, thinking) in PRISM_VARIANTS.items():
        print(f"\n--- prism quality {name} ---", flush=True)
        subprocess.run([sys.executable, str(Path(__file__).with_name("eval_prism.py")), "--model", model,
                        "--samples", str(n), "--thinking", thinking, "--repeat", "3",
                        "--out", str(out_dir / f"prism_{name}.json")], check=False)

    def mean(xs):
        return statistics.mean(xs) if xs else 0

    print("\nsummary (KRW per use: mean / max · 2027 mean)")
    for part, variant in dict.fromkeys((r["part"], r["variant"]) for r in rows):
        group = [r for r in rows if r["part"] == part and r["variant"] == variant and not r["error"]]
        k = KRW_PER_USD
        print(f"{part:9} {variant:10} {mean([r['usd'] for r in group]) * k:6.2f} / "
              f"{max(r['usd'] for r in group) * k:6.2f} · {mean([r['usd_2027'] for r in group]) * k:6.2f}"
              f" · {mean([r['seconds'] for r in group]):.1f}s")


if __name__ == "__main__":
    main()
