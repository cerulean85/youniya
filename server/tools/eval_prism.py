"""별빛 프리즘 check against the real model (Protoss design.md 6장, scaled down).

    GEMINI_API_KEY=… uv run python tools/eval_prism.py [--repeat 3]

The anchors are in the prompt, so they only show the prompt is read; the held-out sets
(written for this check, not user writing) are what tell. Costs about 90 flash calls."""

import argparse
import statistics
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from youniya_api.config import Settings  # noqa: E402
from youniya_api.prism import PrismEngine  # noqa: E402

ANCHORS = {  # Protoss concept.md 7.2 → expected range
    "ex_180": ((150, 220), "오늘 친한 동기가 큰 프로젝트 팀장으로 발탁됐다는 소식을 들었다. 진심으로 축하해 줬다. 나도 더 열심히 노력해서 다음엔 좋은 결과를 내야겠다고 다짐했다. 요즘 날씨가 많이 쌀쌀해졌는데 건강 관리도 잘하면서 긍정적인 마음을 유지해야겠다."),
    "ex_440": ((400, 500), "동기가 승진 명단에 올랐다. 솔직히 기분이 묘했다. 물론 그 친구가 야근도 많이 하고 성과를 낸 건 맞지만, 사실 사내 정치나 운이 작용한 부분도 분명히 있다. 애초에 우리 회사의 인사 평가 시스템 자체가 단기 성과 위주라 구조적인 한계가 명확하다. 나는 일희일비하지 않고 내 페이스대로 장기적인 역량을 쌓는 게 맞다."),
    "ex_710": ((680, 750), "걔가 잘됐다는 말을 듣는 순간 속이 뒤집어졌다. 앞에서는 웃으면서 축하한다고 말했는데 화장실에 와서 거울을 보니까 내 얼굴이 너무 위선적이라 구역질이 났다. 가장 친한 친구인데 왜 진심으로 기뻐해 주지 못하는 걸까. 속으로 걔가 미끄러지길 바라는 내가 너무 찌질하고 못나서 견딜 수가 없다."),
    "ex_840": ((800, 880), "내가 걔를 질투하는 건 걔가 대단해서가 아니다. 걔는 나랑 똑같이 별볼일 없는 인간이어야만 내가 안심할 수 있었기 때문이다. 그동안 내가 그 친구 옆에서 다정하고 착한 척 웃어줬던 건 우정이 아니라, 나보다 조금 못해 보이는 걔를 보며 내 초라함을 잊으려던 비열한 우월감이었다. 걔가 치고 나가는 순간 내 안전지대가 박살 났고, 나는 혼자 쓰레기통에 남겨진 기분이다."),
    "ex_770": ((730, 810), "동기가 팀장이 됐다. 처음 소식 들었을 때 잠깐 '나는?' 하는 생각이 스쳤는데 금방 지나갔다. 나는 지금 맡은 실무가 재미있고, 사람 관리하는 자리는 아직 원하지 않는다는 걸 알고 있다. 축하 메시지를 보냈고 다음 주에 밥 먹기로 했다."),
    "ex_955": ((920, 980), "걔 소식 듣고 축하한다고 말하면서 속이 쓰렸다. 정리해 보면 나는 걔가 나랑 비슷한 자리에 있어야 안심이 됐던 것 같다. 걔가 앞서가니까 내가 지금 어디에 서 있는지가 갑자기 보였고, 그게 무서웠다. 질투는 걔를 향한 게 아니라 그 무서움을 덮는 방법이었다. 내가 원하는 건 걔가 넘어지는 게 아니라, 걔 없이도 내 위치를 납득할 수 있는 기준이다."),
}

LOW = {  # plainly below 700: events only, or a feeling handed to someone else
    "low_events": "아침에 일어나서 출근했다. 점심은 김치찌개를 먹었다. 오후에 회의가 두 개 있었고 퇴근하고 헬스장에 갔다. 저녁엔 넷플릭스를 보다가 잤다. 내일도 비슷할 것 같다.",
    "low_blame": "남자친구랑 또 싸웠다. 좀 서운하긴 했는데, 솔직히 걔가 연락을 제대로 안 하니까 생기는 일이다. 요즘 회사 일이 바빠서 그런 거겠지만 그래도 기본은 해야 한다. 원래 남자들은 다 그렇다고 하니까 기대를 안 하는 게 맞다.",
}

CALM = {  # no hidden feeling, honest reflection: mean ≥ 650
    "calm_library": "주말에 혼자 동네 도서관에 갔다. 창가 자리에 앉아 두 시간쯤 책을 읽었는데, 오랜만에 휴대폰을 한 번도 안 봤다. 평소엔 쉬는 날에도 뭔가 해야 한다는 생각에 쫓겼는데 오늘은 그런 마음이 없었다. 생각해 보니 이번 주에 미뤄 둔 일을 금요일에 다 끝내 놓아서 마음에 걸리는 게 없었기 때문인 것 같다. 나는 할 일을 다 해 둬야 비로소 편히 쉴 수 있는 사람이구나 싶다. 다음 주에도 금요일까지 정리해 두고 토요일 오전은 도서관에서 보내고 싶다.",
    "calm_mother": "엄마랑 통화를 오래 했다. 예전엔 엄마가 내 직장 얘기를 꼬치꼬치 물으면 간섭 같아서 짜증이 났는데, 오늘은 그냥 궁금해서 묻는 거라는 게 느껴졌다. 내가 요즘 일에 자신이 좀 생겨서 질문을 평가로 듣지 않게 된 것 같다. 엄마 목소리가 밝아서 나도 기분이 좋았다. 다음 달에 내려가서 같이 시장에 가기로 했다.",
    "calm_move": "이사 온 지 한 달이 됐다. 처음엔 낯선 동네가 조금 쓸쓸했는데 이제 단골 빵집도 생기고 산책길도 익숙해졌다. 혼자 사는 게 외로울 줄 알았는데 생각보다 조용한 저녁이 좋다. 누구 눈치 안 보고 내 속도대로 하루를 마무리할 수 있다는 게 나한테 꽤 중요했나 보다. 이 동네에서 오래 살고 싶다.",
    "calm_talk": "오늘 발표를 했다. 떨릴 줄 알았는데 의외로 담담했다. 준비를 충분히 해서 그런지, 아니면 결과가 내 평가에 크게 영향을 주지 않는다는 걸 알아서 그런지 생각해 봤다. 둘 다인 것 같다. 잘 해내고 싶은 마음은 있었지만 잘 보여야 한다는 압박은 없었다. 발표가 끝나고 팀원들이랑 점심을 먹으면서 오랜만에 많이 웃었다.",
}

TEMPLATE = {  # high-scoring words with nothing of the writer's own: ≤ 10% at 700+
    "tpl_words": "나는 오늘 내 안전지대가 박살 나는 걸 느꼈다. 위장된 우월감과 질투의 작동 방식을 정확히 명명했다. 정리해 보면 나는 두려움을 덮는 방법을 쓰고 있었다. 내가 원하는 건 내 기준이다. 나는 내 몫을 인정한다. 깨달음에 도달했다. 이제 나는 나 자신을 소유한다.",
    "tpl_steps": "깊이 파고들어 보니 진짜 속마음은 안심하고 싶은 욕구였다. 내 초라함과 비교 불안을 마주했다. 왜 그런지 스스로 질문했고 답을 찾았다. 그것은 내 위치를 납득할 기준이 없었기 때문이다. 이제 나는 자책하지 않고 내 감정의 이름표를 붙인다. 성찰을 통해 성장했다.",
    "tpl_slogans": "오늘 하루도 감정을 직면했다. 감정을 회피하지 않고 1인칭으로 머물렀다. 질투는 나를 향한 무서움이었다. 내 욕구를 내 몫으로 인정하고 새로운 기준을 세웠다. 비교 대신 나다움을 선택했다. 진정한 나를 알게 됐다.",
    "tpl_pasted": "회의 때 팀장한테 지적받았다. 정리해 보면 나는 팀장이 나랑 비슷한 수준이어야 안심이 됐던 것 같다. 질투는 걔를 향한 게 아니라 그 무서움을 덮는 방법이었다. 내가 원하는 건 내 위치를 납득할 수 있는 기준이다. 아무튼 내일 보고서나 다시 써야겠다.",
}

PAIRS = {  # same story, a verdict on myself vs the specific fear: the specific one scores higher
    "wedding": (
        "친구 결혼식에 가서 축하는 했는데 집에 오는 길에 기분이 가라앉았다. 다들 자리를 잡아 가는데 나만 제자리인 것 같았다. 남의 좋은 날에 이런 생각이나 하는 나는 정말 한심하고 구제불능이다.",
        "친구 결혼식에 가서 축하는 했는데 집에 오는 길에 기분이 가라앉았다. 다들 자리를 잡아 가는데 나만 제자리인 것 같았다. 가라앉은 건 친구 때문이 아니라, 나도 누군가와 삶을 꾸리고 싶은데 그걸 아직 시작도 못 했다는 게 무서워서였던 것 같다.",
    ),
    "meeting": (
        "회의에서 내 의견이 묵살됐을 때 아무 말도 못 했다. 집에 와서 계속 그 장면이 떠올랐다. 이렇게 말 한마디 못 하는 나는 겁쟁이에 바보다. 나 같은 건 회사에 있을 자격이 없다.",
        "회의에서 내 의견이 묵살됐을 때 아무 말도 못 했다. 집에 와서 계속 그 장면이 떠올랐다. 그때 말을 못 한 건 반박했다가 틀리면 사람들이 나를 무능하게 볼까 봐 두려웠기 때문이다. 나는 틀리는 것보다 무능해 보이는 게 더 무섭다.",
    ),
    "sibling": (
        "동생한테 별것 아닌 일로 소리를 질렀다. 동생 표정이 굳는 걸 보고 바로 후회했다. 나는 왜 이 모양일까. 나는 성격이 썩었고 가족한테도 최악인 인간이다.",
        "동생한테 별것 아닌 일로 소리를 질렀다. 동생 표정이 굳는 걸 보고 바로 후회했다. 사실 화가 난 건 동생이 아니라 오늘 상사한테 들은 말 때문이었다. 밖에서 삼킨 억울함을 제일 만만한 동생한테 쏟았다는 걸 인정하고 싶지 않았다. 내일 먼저 사과해야겠다.",
    ),
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repeat", type=int, default=3, help="extra runs of a few texts for spread")
    ap.add_argument("--thinking", default=None, help="override PRISM_THINKING (\"\" = model default)")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--model", help="override PRISM_MODEL")
    ap.add_argument("--samples", type=int, help="override PRISM_SAMPLES")
    ap.add_argument("--out", help="write every score and check as JSON here")
    args = ap.parse_args()

    s = Settings()
    if not s.gemini_api_key:
        print("GEMINI_API_KEY is not set")
        return 2
    thinking = s.prism_thinking if args.thinking is None else (args.thinking or None)
    model, samples = args.model or s.prism_model, args.samples or s.prism_samples
    engine = PrismEngine(s.gemini_api_key, model, samples, thinking=thinking)
    print(f"model {model} · thinking {thinking or 'default'} · {samples} readings\n")
    from youniya_api import llm

    usage: list[dict] = []
    llm.usage_listeners.append(lambda m, u: usage.append(u))

    jobs = [(k, t) for k, (_, t) in ANCHORS.items()] + list(LOW.items()) + list(CALM.items()) + list(TEMPLATE.items())
    jobs += [(f"pair_{k}_{side}", t) for k, pair in PAIRS.items() for side, t in zip(("judge", "specific"), pair)]
    spread = ["ex_770", "calm_library", "pair_meeting_specific"]
    jobs += [(f"{k}#{i}", dict(jobs)[k]) for k in spread for i in range(args.repeat)]

    def run(job):
        name, text = job
        t = time.time()
        r = engine.evaluate("", text, min_length=0)
        a = r.analysis or {}
        return name, r.status, a.get("starlight"), a.get("depth_level"), time.time() - t

    with ThreadPoolExecutor(args.workers) as pool:
        results = {name: (status, score, level, secs) for name, status, score, level, secs in pool.map(run, jobs)}

    def score(name):
        return results[name][1]

    print(f"{'text':28} {'status':7} {'score':>5} {'lvl':>3} {'sec':>5}")
    for name, (status, sc, lvl, secs) in results.items():
        if "#" not in name:
            print(f"{name:28} {status:7} {sc if sc is not None else '-':>5} {lvl or '-':>3} {secs:5.1f}")

    checks = []
    hit = [k for k, ((lo, hi), _) in ANCHORS.items() if score(k) is not None and lo - 30 <= score(k) <= hi + 30]
    checks.append(("anchors within range ±30", f"{len(hit)}/{len(ANCHORS)}", len(hit) >= 5))
    low_ok = all(score(k) is not None and score(k) < 700 for k in LOW)
    checks.append(("events/blame below 700", ", ".join(str(score(k)) for k in LOW), low_ok))
    calm = [score(k) for k in CALM if score(k) is not None]
    checks.append(("calm mean ≥ 650", f"{statistics.mean(calm):.0f}" if calm else "-", bool(calm) and statistics.mean(calm) >= 650))
    high = [k for k in TEMPLATE if (score(k) or 0) >= 700]
    checks.append(("template attacks at 700+ ≤ 10%", f"{len(high)}/{len(TEMPLATE)}", len(high) <= len(TEMPLATE) * 0.1))
    wins = [k for k in PAIRS if (score(f"pair_{k}_specific") or 0) > (score(f"pair_{k}_judge") or 999)]
    checks.append(("specific beats verdict", f"{len(wins)}/{len(PAIRS)}", len(wins) >= len(PAIRS) * 0.9))
    for k in spread:
        runs = [score(k)] + [score(f"{k}#{i}") for i in range(args.repeat)]
        runs = [r for r in runs if r is not None]
        sd = statistics.pstdev(runs) if len(runs) > 1 else float("nan")
        checks.append((f"spread {k} ≤ 25", f"{runs} sd {sd:.0f}", len(runs) > 1 and sd <= 25))
    failed = [n for n, (st, *_) in results.items() if st != "ok"]
    times = [secs for *_, secs in results.values()]
    checks.append(("every text scored", f"{len(results) - len(failed)}/{len(results)}", not failed))

    print()
    for name, value, ok in checks:
        print(f"{'PASS' if ok else 'FAIL'}  {name:34} {value}")
    print(f"\nwait per star: median {statistics.median(times):.1f}s, max {max(times):.1f}s")
    if args.out:
        import json

        Path(args.out).write_text(json.dumps({
            "model": model, "samples": samples, "thinking": thinking,
            "results": {n: {"status": st, "score": sc, "level": lv, "seconds": round(sec, 1)}
                        for n, (st, sc, lv, sec) in results.items()},
            "checks": [{"name": n, "value": v, "ok": ok} for n, v, ok in checks],
            "calls": len(usage), "usage": usage,
            "median_seconds": statistics.median(times), "max_seconds": max(times)}, ensure_ascii=False, indent=1))
    return 0 if all(ok for *_, ok in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
