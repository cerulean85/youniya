"""마음 망원경 (Protoss psy-cognitive-radar) and 성운 이야기 서사 다듬기.

Numbers come from the stars' own analyses; the model only names, notes and asks.
Quoted sentences must appear in the writing unchanged."""

from dataclasses import dataclass

from .llm import generate_json
from .rules import MOOD_LABELS

LENSES = (("depth", "별의 깊이"), ("clarity", "빛의 선명함"), ("weight", "마음의 무게"))

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
- star_name: 이 별(들)에 붙일 이름. "~별"로 끝나는 10자 안팎의 시적인 이름
- notes: {"depth": …, "clarity": …, "weight": …} 각 렌즈에서 관찰한 사실 한 문장 (~요체)
  depth=별의 깊이(사건을 지나 속마음까지 내려간 정도), clarity=빛의 선명함(감정을 또렷이 구분한 정도),
  weight=마음의 무게(남이 아니라 내 마음으로 품어낸 정도)
- evidence: 위 관찰의 근거가 된 원문 문장 하나. 원문을 한 글자도 바꾸지 않는다
- question: 스스로에게 물어볼 질문 한 문장. 답을 유도하지 않는다
- signals: [{"star_id": …, "sentence": …}] 감정의 신호가 머문 원문 문장 최대 5개
"""

STORY_PROMPT = """# Role
당신은 '성운 이야기'의 문장 사이를 잇는 사람이다. 아래 문장들은 사용자가 쓴 원문이며 절대 바꾸지 않는다.
각 문장 사이(✦ 자리)에 들어갈 짧은 이음말만 쓴다. 해석, 평가, 조언을 더하지 않는다. 한 줄 25자 안팎, ~요체.

# 출력
{"bridges": [문장 수보다 하나 적은 개수의 이음말]}
"""


@dataclass
class StarText:
    id: str
    title: str
    body: str
    created_at: str
    analysis: dict


def build_report(stars: list[StarText], api_key: str | None, model: str) -> dict:
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
        text = _model_text(stars, api_key, model)  # raises on failure; caller charges nothing

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
        "lenses": [{"key": k, "label": label, "value": lens_values[k], "note": text["notes"].get(k, "")}
                   for k, label in LENSES],
        "emotions": emotions,
        "evidence": evidence,
        "question": text["question"],
        "signals": signals,
        "star_count": n,
        "period": {"from": min(s.created_at for s in stars), "to": max(s.created_at for s in stars)},
    }


def _model_text(stars: list[StarText], api_key: str, model: str) -> dict:
    parts = [f"## star_id: {s.id}\n제목: {s.title}\n\"\"\"\n{s.body}\n\"\"\"" for s in stars]
    out = generate_json(api_key, model, TELESCOPE_PROMPT + "\n\n# 별들\n" + "\n\n".join(parts), temperature=0.3,
                        timeout=90.0)
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
    }


def story_bridges(sentences: list[str], api_key: str | None, model: str) -> list[str]:
    """83 서사 다듬기: lines for the ✦ places between the original sentences."""
    need = max(0, len(sentences) - 1)
    if not api_key:
        fallback = ("그리고 시간이 조금 흘렀어요.", "그 마음은 다른 날에도 이어졌어요.", "빛은 천천히 방향을 바꾸었어요.")
        return [fallback[i % len(fallback)] for i in range(need)]
    listed = "\n".join(f"{i + 1}. {s}" for i, s in enumerate(sentences))
    out = generate_json(api_key, model, f"{STORY_PROMPT}\n\n# 문장\n{listed}", temperature=0.5, timeout=90.0)
    bridges = [str(b) for b in out.get("bridges", [])]
    if len(bridges) != need:
        raise ValueError("bridge count mismatch")
    return bridges
