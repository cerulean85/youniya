"""17.6 측정 방식 시험: the old prism prompt against the new one, on the same 30 writings.

    GEMINI_API_KEY=… uv run python tools/compare_prism.py [--repeat 2] [--out result.json]

Each writing is read --repeat times by each version with the server's settings (model, one
reading, thinking). The new version may ship only when
  - the mean starlight moves by 30 or less, and
  - the order of the three scores (depth/400, clarity/300, weight/300) flips in at most
    3 of the 30 writings (10%).
Also printed: each score's rank correlation across the writings, and the cost of the run.
Costs about 30 × 2 × --repeat flash calls (about 1,000 KRW at --repeat 2). --baseline reads the
old prompt twice instead: the flips it finds are the noise the new version is judged against."""

import argparse
import json
import statistics
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api import ai_cost, llm  # noqa: E402
from youniya_api.config import Settings  # noqa: E402
from youniya_api.prism import PrismEngine, engine as prism_engine  # noqa: E402
from youniya_api.prism.prompt import PREFIX as NEW_PREFIX  # noqa: E402
from youniya_api.rules import PRISM_VERSION  # noqa: E402

from eval_prism import ANCHORS, CALM, LOW, PAIRS, TEMPLATE  # noqa: E402
from prism_v0_prompt import PREFIX as OLD_PREFIX  # noqa: E402
from seed_texts import REVIEW_FLOATED  # noqa: E402

MAX_MEAN_SHIFT = 30
MAX_FLIPS = 3


def writings() -> dict[str, str]:
    out = {k: v[1] for k, v in ANCHORS.items()} | LOW | CALM | TEMPLATE
    for k, (a, b) in PAIRS.items():
        out[f"{k}_a"], out[f"{k}_b"] = a, b
    for i, (_, _, body) in enumerate(REVIEW_FLOATED[:30 - len(out)]):
        out[f"seed_{i}"] = body
    return out


def order(scores: dict) -> tuple[str, ...]:
    share = {"depth": scores["depth"] / 400, "clarity": scores["clarity"] / 300, "weight": scores["weight"] / 300}
    return tuple(sorted(share, key=lambda k: -share[k]))


def spearman(xs: list[float], ys: list[float]) -> float:
    def ranks(v):
        idx = sorted(range(len(v)), key=lambda i: v[i])
        r = [0.0] * len(v)
        for pos, i in enumerate(idx):
            r[i] = pos
        return r
    rx, ry = ranks(xs), ranks(ys)
    mx, my = statistics.mean(rx), statistics.mean(ry)
    cov = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    sx = sum((a - mx) ** 2 for a in rx) ** 0.5
    sy = sum((b - my) ** 2 for b in ry) ** 0.5
    return round(cov / (sx * sy), 3) if sx and sy else 0.0


def read(prefix: str, body: str, settings: Settings, repeat: int) -> dict | None:
    prism_engine.PREFIX = prefix  # the engine sends this fixed part ahead of the writing
    eng = PrismEngine(settings.gemini_api_key, settings.prism_model, 1, thinking=settings.prism_thinking)
    got = [eng.evaluate("", body, min_length=0) for _ in range(repeat)]
    ok = [r.analysis for r in got if r.status == "ok"]
    if not ok:
        return None
    return {"starlight": statistics.mean(a["starlight"] for a in ok),
            "scores": {k: statistics.mean(a["scores"][k] for a in ok) for k in ("depth", "clarity", "weight")},
            "readings": len(ok), "sample": ok[0]}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repeat", type=int, default=2)
    ap.add_argument("--out", default=None)
    # The old prompt against itself: how often the score order flips with no change at all.
    ap.add_argument("--baseline", action="store_true")
    a = ap.parse_args()
    settings = Settings()
    if not settings.gemini_api_key:
        sys.exit("GEMINI_API_KEY is not set")
    cost = {"old": 0.0, "new": 0.0}
    phase = {"now": "old"}
    llm.usage_listeners.append(lambda model, usage: cost.__setitem__(phase["now"], cost[phase["now"]] + ai_cost.krw(model, usage)))

    texts = writings()
    results: dict[str, dict] = {}
    for version, prefix in (("old", OLD_PREFIX), ("new", OLD_PREFIX if a.baseline else NEW_PREFIX)):
        phase["now"] = version
        with ThreadPoolExecutor(max_workers=6) as pool:
            got = dict(zip(texts, pool.map(lambda body: read(prefix, body, settings, a.repeat), texts.values())))
        for k, r in got.items():
            results.setdefault(k, {})[version] = r
        print(f"{version}: {sum(r is not None for r in got.values())}/{len(texts)} read · {cost[version]:.1f}원", flush=True)

    both = {k: v for k, v in results.items() if v.get("old") and v.get("new")}
    shift = statistics.mean(v["new"]["starlight"] - v["old"]["starlight"] for v in both.values())
    flips = [k for k, v in both.items() if order(v["old"]["scores"]) != order(v["new"]["scores"])]
    corr = {s: spearman([v["old"]["scores"][s] for v in both.values()], [v["new"]["scores"][s] for v in both.values()])
            for s in ("depth", "clarity", "weight")}
    passed = abs(shift) <= MAX_MEAN_SHIFT and len(flips) <= MAX_FLIPS and len(both) == len(texts)

    print(f"\n{'writing':14} {'old':>6} {'new':>6} {'Δ':>6}  order old → new")
    for k, v in both.items():
        o, n = v["old"], v["new"]
        print(f"{k:14} {o['starlight']:6.0f} {n['starlight']:6.0f} {n['starlight'] - o['starlight']:+6.0f}  "
              f"{'/'.join(order(o['scores']))} → {'/'.join(order(n['scores']))}{'  ← flipped' if k in flips else ''}")
    print(f"\n{'before vs before (baseline)' if a.baseline else PRISM_VERSION + ' vs before'}: mean starlight shift {shift:+.1f} (limit ±{MAX_MEAN_SHIFT}), "
          f"score order flipped in {len(flips)}/{len(both)} (limit {MAX_FLIPS}), rank correlation {corr}")
    print(f"cost {cost['old'] + cost['new']:.1f}원 · {'PASS: can ship' if passed else 'FAIL: do not ship'}")
    if a.out:
        Path(a.out).write_text(json.dumps({"version": PRISM_VERSION, "repeat": a.repeat, "shift": shift, "flips": flips,
                                           "correlation": corr, "passed": passed, "cost_krw": cost,
                                           "results": results}, ensure_ascii=False, indent=1))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
