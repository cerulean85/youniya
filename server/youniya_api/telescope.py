"""마음 망원경 (Protoss psy-cognitive-radar) and 성운 이야기 서사 다듬기.

Numbers come from the stars' own analyses; the model only names, notes and asks.
Quoted sentences must appear in the writing unchanged."""

from dataclasses import dataclass

from .llm import generate_json
from .rules import MOOD_LABELS

LENSES = (("depth", "별의 깊이"), ("clarity", "빛의 선명함"), ("weight", "마음의 무게"))
# 17.3 마음을 흐리게 하는 것들
FOG_KINDS = {"step_back": "한 걸음 물러서기", "unnamed": "이름 없이 지나간 감정", "blaming": "남 탓",
             "self_blame": "자신 몰아세우기", "overgeneral": "지나친 일반화"}


def _flow(flow, emotions: list[dict]) -> dict:
    """{start, middle, end}: a mood each; the strongest mood where the model gave none."""
    top = emotions[0]["mood"] if emotions else "calm"
    flow = flow if isinstance(flow, dict) else {}
    return {k: flow.get(k) if flow.get(k) in MOOD_LABELS else top for k in ("start", "middle", "end")}

_STAR_NAMES = {
    "calm": "기다림이 머문 별",
    "sorrow": "젖은 빛을 품은 별",
    "anger": "뜨거움을 지난 별",
    "insight": "맑게 깨어난 별",
}

TELESCOPE_PROMPT = """# Role
당신은 '마음 망원경'이다. 사용자가 띄운 별(일기) 몇 편을 함께 읽고, 그 사이에 흐르는 마음의 결을 비춘다.
평가나 처방이 아니라 곁에서 함께 바라본 기록을 남긴다. 진단하지 않고, 조언하지 않고, 인격을 규정하지 않는다.
방어기제나 생각의 습관이 보이면 단정하지 말고 "…일지도 몰라요"처럼 가능성으로만 말한다.

# 출력 (JSON 객체 하나)
- star_name: 이 별(들)에 붙일 이름. "~별"로 끝나는 10자 안팎의 시적인 이름. 맞춤법대로 띄어 쓴다(예: "스스로를 비추는 별", "가만히 머무는 별")
- notes: {"depth": …, "clarity": …, "weight": …} 각 렌즈에서 관찰한 사실 한 문장 (~요체)
  depth=별의 깊이(사건을 지나 속마음까지 내려간 정도), clarity=빛의 선명함(감정을 또렷이 구분한 정도),
  weight=마음의 무게(남이 아니라 내 마음으로 품어낸 정도)
- evidence: 위 관찰의 근거가 된 원문 문장 하나. 원문을 한 글자도 바꾸지 않는다
- question: 스스로에게 물어볼 질문 한 문장. 답을 유도하지 않는다
- fog_items: 마음을 흐리게 하는 생각의 습관이 보이는 곳 0~5개. [{"kind": …, "sentence": …, "note": …}]
  kind는 다음 중 하나: step_back(한 걸음 물러서기: 느낌 대신 상황 설명으로 비켜 감), unnamed(이름 없이 지나간 감정),
  blaming(남 탓), self_blame(자신 몰아세우기), overgeneral(지나친 일반화: "늘", "항상", "다들" 같은 말로 넓힘).
  sentence는 원문 문장 그대로, note는 그 문장에서 본 것을 가능성으로 말하는 한 문장(~일지도 몰라요). 없으면 빈 배열
- mood_flow: {"start": …, "middle": …, "end": …} 글의 처음·가운데·끝에 머문 감정. 각각 calm, sorrow, anger, insight 중 하나
- mood_interpretation: 감정이 그렇게 흘러간 모습을 비추는 1~2문장. 조언하지 않는다

# 말투
- notes와 question은 "~어요/~해요/~나요" 체로 통일한다. "~셨어요", "~계셔요", "~하시나요"처럼 높이는 "-시-"는 쓰지 않는다
- 사용자를 "당신"이라고 부르지 않는다
- signals: [{"star_id": …, "sentence": …}] 감정의 신호가 머문 원문 문장 최대 5개
"""

# Two tries of 45 s fit Vercel's 120 s limit. One telescope call took over 90 s in 11 (20261107).
MODEL_TIMEOUT = 45.0


@dataclass
class StarText:
    id: str
    title: str
    body: str
    created_at: str
    analysis: dict


def build_report(stars: list[StarText], api_key: str | None, model: str, thinking: str | None = None,
                 caches=None) -> dict:
    """10 마음 망원경 리포트 and 88 관측 연출 data."""
    n = len(stars)
    lens_values = {k: round(sum(s.analysis[k] for s in stars) / n, 3) for k, _ in LENSES}

    weights: dict[str, float] = {}
    for s in stars:
        for m in s.analysis["moods"]:
            weights[m["mood"]] = weights.get(m["mood"], 0) + m["share"]
    total = sum(weights.values()) or 1
    emotions = [{"mood": m, "label": MOOD_LABELS[m], "percent": round(w * 100 / total)}
                for m, w in sorted(weights.items(), key=lambda kv: -kv[1])]

    brightest = max(stars, key=lambda s: s.analysis["starlight"])
    text = _mock_text(brightest, emotions[0]["mood"] if emotions else "calm")
    if api_key:
        text = _model_text(stars, api_key, model, thinking, caches)  # raises on failure; caller charges nothing

    bodies = {s.id: s.body for s in stars}
    evidence = text.get("evidence", "")
    if not any(evidence and evidence in b for b in bodies.values()):
        evidence = brightest.analysis["impact_quote"]
    signals = [
        {"star_id": g["star_id"], "sentence": g["sentence"]}
        for g in text.get("signals", [])
        if g.get("sentence") and g["sentence"] in bodies.get(g.get("star_id"), "")
    ][:5] or [{"star_id": s.id, "sentence": q} for s in stars for q in s.analysis["signal_sentences"]][:5]

    return {
        "star_name": text["star_name"],
        # 17.3: the score and its reason are the prism's, copied, never read again.
        "lenses": [{"key": k, "label": label, "value": lens_values[k], "note": text["notes"].get(k, ""),
                    "score": stars[-1].analysis["scores"][k] if n == 1 else None,
                    "reason": stars[-1].analysis.get(f"{k}_reason") if n == 1 else None}
                   for k, label in LENSES],
        "fog_items": [{"kind": f["kind"], "label": FOG_KINDS[f["kind"]], "sentence": f["sentence"],
                       "note": f.get("note", "")}
                      for f in text.get("fog_items") or []
                      if isinstance(f, dict) and f.get("kind") in FOG_KINDS
                      and f.get("sentence") and any(f["sentence"] in b for b in bodies.values())][:5],
        "mood_flow": _flow(text.get("mood_flow"), emotions),
        "mood_interpretation": text.get("mood_interpretation") or "",
        "emotions": emotions,
        "evidence": evidence,
        "question": text["question"],
        "signals": signals,
        "star_count": n,
        "period": {"from": min(s.created_at for s in stars), "to": max(s.created_at for s in stars)},
    }


def _model_text(stars: list[StarText], api_key: str, model: str, thinking: str | None = None, caches=None) -> dict:
    parts = [f"## star_id: {s.id}\n제목: {s.title}\n\"\"\"\n{s.body}\n\"\"\"" for s in stars]
    prefix = TELESCOPE_PROMPT + "\n\n"
    cache = caches.for_request("telescope", model, prefix) if caches else None
    out = generate_json(api_key, model, "# 별들\n" + "\n\n".join(parts), prefix=prefix, cache=cache,
                        temperature=0.3,
                        thinking=thinking, timeout=MODEL_TIMEOUT, retries=1)
    if not isinstance(out.get("notes"), dict) or not out.get("star_name") or not out.get("question"):
        raise ValueError("incomplete telescope output")
    return out


def _mock_text(star: StarText, top_mood: str) -> dict:
    a = star.analysis
    return {
        "star_name": _STAR_NAMES[top_mood],
        "notes": {
            "depth": "사건을 지나 속마음 가까이까지 내려가 마주했어요." if a["depth_level"] >= 5
            else "일어난 일을 차분히 따라가며 적었어요.",
            "clarity": "여러 마음의 결이 또렷하게 구분돼요." if a["clarity"] >= 0.6
            else "마음의 이름이 아직 조금 흐릿해요.",
            "weight": "마음을 밖이 아닌 내 안의 것으로 품어냈어요." if a["weight"] >= 0.6
            else "마음의 일부를 바깥 사정에 맡겨 두었어요.",
        },
        "evidence": a["impact_quote"],
        "question": a["rewrite_question"],
        "signals": [],
        "fog_items": [],
        "mood_interpretation": "마음이 한 결로 머물렀다가 천천히 가라앉았어요.",
    }


MONTHLY_PROMPT = """# Role
당신은 '월간 마음 리포트'를 쓴다. 사용자가 한 달 동안 띄운 별(일기)을 함께 읽고, 그달의 마음이 어떻게 흘렀는지 비춘다.
평가나 처방이 아니라 곁에서 함께 바라본 기록이다. 진단하지 않고, 조언하지 않고, 인격을 규정하지 않는다.
원문에 없는 사건, 장소, 사람, 감정을 지어내지 않는다. 별들에 실제로 쓰인 것만 말한다.

# 출력 (JSON 객체 하나)
- title: 이 달에 붙일 이름. "~달"로 끝나는 12자 안팎의 시적인 이름. 맞춤법대로 띄어 쓴다(예: "천천히 숨을 고른 달")
- intro: 이 달을 소개하는 한 문장
- notes: {"depth": …, "clarity": …, "weight": …} 각 렌즈에서 한 달 동안의 흐름을 한 문장씩
  depth=별의 깊이(사건을 지나 속마음까지 내려간 정도), clarity=빛의 선명함(감정을 또렷이 구분한 정도),
  weight=마음의 무게(남이 아니라 내 마음으로 품어낸 정도)
- question: 다음 달의 나에게 건네는 질문 한 문장. 답을 유도하지 않는다

# 감정 표현
- 원문의 감정 표현을 다른 말로 바꾸거나 더 강하게 말하지 않는다. 예: 원문이 "쓸모없는 사람이 될까 봐 무서웠다"이면 "버려질까 무서웠던"으로 바꾸지 않는다
- 감정을 말할 때는 원문의 낱말을 그대로 쓰거나 더 약하게만 표현한다

# 말투
- 모든 문장은 "~어요/~해요/~나요" 체로 통일한다. 높이는 "-시-"("~셨어요")는 쓰지 않고, 사용자를 "당신"이라고 부르지 않는다
- 점수, 숫자, 순위를 말하지 않는다
"""

# What the model reads of a month (기획 확정 20261107): each star up to 1,500 characters, cut at a
# sentence end, and at most the first 40 stars floated. The numbers still come from every star.
MONTHLY_MAX_CHARS = 1500
MONTHLY_MAX_STARS = 40


def clip(text: str, limit: int = MONTHLY_MAX_CHARS) -> str:
    """The start of the text, at most `limit` characters, ending at a sentence end when there is one."""
    if len(text) <= limit:
        return text
    head = text[:limit]
    cut = max(head.rfind(c) for c in ".!?\n")
    return head[:cut + 1].rstrip() if cut > 0 else head



def build_monthly(month: str, stars: list[StarText], api_key: str | None, model: str,
                  thinking: str | None = None, cache: str | None = None) -> dict:
    """월간 마음 리포트 (Figma 123). Numbers come from the stars' analyses; the brightest star's
    sentence is quoted as written."""
    base = build_report(stars, None, model)  # lens values, emotions and period, without the model
    brightest = max(stars, key=lambda s: s.analysis["starlight"])
    quote = brightest.analysis["impact_quote"]
    top = base["emotions"][0]["mood"] if base["emotions"] else "calm"
    text = {"title": {"calm": "천천히 숨을 고른 달", "sorrow": "젖은 빛을 말린 달", "anger": "뜨거움이 지나간 달",
                      "insight": "맑게 깨어난 달"}[top],
            "intro": f"이번 달에는 별 {len(stars)}개가 떴어요.",
            "notes": {lens["key"]: lens["note"] for lens in base["lenses"]},
            "question": brightest.analysis["rewrite_question"]}
    if api_key:
        parts = [f"## {s.created_at[:10]} · {s.title}\n\"\"\"\n{clip(s.body)}\n\"\"\""
                 for s in stars[:MONTHLY_MAX_STARS]]
        prefix, prompt = MONTHLY_PROMPT + "\n\n", f"# {month}의 별들\n" + "\n\n".join(parts)
        for attempt in range(2):  # a malformed answer now and then (1 in 4, 20261107): ask once more
            out = generate_json(api_key, model, prompt, prefix=prefix, cache=cache, temperature=0.3,
                                thinking=thinking,
                                timeout=MODEL_TIMEOUT, retries=1)
            notes = out.get("notes")
            if (isinstance(notes, dict) and all(isinstance(notes.get(k), str) and notes[k] for k, _ in LENSES)
                    and all(isinstance(out.get(k), str) and out[k] for k in ("title", "intro", "question"))):
                break
        else:
            raise ValueError("incomplete monthly report")
        text = {"title": out["title"], "intro": out["intro"], "notes": notes, "question": out["question"]}
    return {
        "month": month,
        "title": text["title"],
        "intro": text["intro"],
        "lenses": [{"key": lens["key"], "label": lens["label"], "value": lens["value"],
                    "note": text["notes"][lens["key"]]} for lens in base["lenses"]],
        "emotions": base["emotions"],
        "brightest": {"star_id": brightest.id, "title": brightest.title, "sentence": quote},
        "question": text["question"],
        "star_count": len(stars),
        "period": base["period"],
    }
