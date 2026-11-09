"use client";

import Link from "next/link";
import { useActionState, useEffect, useRef, useState } from "react";
import { useFormStatus } from "react-dom";
import { Info, Lock, StarFilled } from "@/components/icons";
import { MIN_FLOAT_LENGTH, MOODS } from "@/lib/format";
import type { Draft, Mood } from "@/lib/types";
import { createStar, saveDraft } from "./actions";
import styles from "./write.module.css";

const STAR_COST = 5;

export function WriteForm({ draft, freeStarToday, coins }: { draft: Draft; freeStarToday: number; coins: number }) {
  const [mood, setMood] = useState<Mood>(draft?.mood ?? "calm");
  const [title, setTitle] = useState(draft?.title ?? "");
  const [body, setBody] = useState(draft?.body ?? "");
  const [saved, setSaved] = useState<string | null>(draft ? "이전에 쓰던 글을 불러왔어요" : null);
  const [state, action] = useActionState(createStar, null);
  const first = useRef(true);

  // Autosave a moment after typing stops.
  useEffect(() => {
    if (first.current) { first.current = false; return; }
    const t = setTimeout(async () => {
      try {
        await saveDraft({ mood, title, body });
        setSaved(`임시 저장됨 · ${new Intl.DateTimeFormat("ko-KR", { hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date())}`);
      } catch { setSaved("임시 저장하지 못했어요"); }
    }, 1200);
    return () => clearTimeout(t);
  }, [mood, title, body]);

  const length = body.trim().length;
  const canFloat = length >= MIN_FLOAT_LENGTH;
  const freeLeft = freeStarToday > 0;

  return (
    <form action={action} className={styles.body}>
      <input type="hidden" name="mood" value={mood} />
      <div className={`card ${styles.editor}`}>
        <div className={styles.moods} role="radiogroup" aria-label="오늘의 기분">
          {MOODS.map((m) => (
            <button key={m.key} type="button" role="radio" aria-checked={mood === m.key} className={styles.mood}
              style={{ ["--c" as string]: m.color }} onClick={() => setMood(m.key)}>{m.label}</button>
          ))}
        </div>
        <input name="title" className={`h1 ${styles.title}`} placeholder="제목 없는 별" value={title} maxLength={60}
          onChange={(e) => setTitle(e.target.value)} aria-label="제목" />
        <textarea name="body" className={`journal ${styles.text}`} placeholder="오늘은 어떤 마음이 머물렀나요? 떠오르는 대로 적어 주세요."
          value={body} maxLength={20000} onChange={(e) => setBody(e.target.value)} aria-label="본문" />
        <div className={styles.footer}>
          <span className="caption faint">{length.toLocaleString("ko-KR")}자{!canFloat && length > 0 ? ` · ${MIN_FLOAT_LENGTH - length}자 더 쓰면 별빛을 받을 수 있어요` : ""}</span>
          <span className={styles.spacer} />
          {saved && <span className="caption faint">{saved}</span>}
          <Submit mode="keep" label="별빛 없이 띄우기" style="btn-secondary" disabled={length === 0} />
          <Submit mode="float" label="별빛 받고 띄우기" style="btn-primary" disabled={!canFloat} />
        </div>
      </div>
      <aside className={styles.side}>
        <div className={styles.banner}>
          <Info size={18} />
          {freeLeft ? "오늘 무료 별빛 받기가 1번 남았어요." : `오늘 무료 별빛 받기를 썼어요. 별빛을 받으면 ${STAR_COST}코인이 들어요 (보유 ${coins}).`}
        </div>
        {state?.error && (
          <div className={styles.error} role="alert">
            {state.error}
            {state.code === "insufficient_coins" && <Link href="/coins" className={styles.link}>코인 충전하기</Link>}
          </div>
        )}
        <div className={`card ${styles.tips}`}>
          <span className="label-m">쓰는 동안</span>
          <ul>
            <li>떠오르는 대로 적어도 괜찮아요. 맞춤법은 신경 쓰지 않아도 돼요.</li>
            <li>{MIN_FLOAT_LENGTH}자를 넘으면 별빛을 받을 수 있어요. 짧은 날은 별빛 없이 띄워도 괜찮아요.</li>
            <li>별빛을 받으면 별빛 프리즘이 마음의 결을 읽어 별빛을 매겨요. 별빛 없이 띄우면 글만 별이 돼요.</li>
          </ul>
        </div>
        <p className={`caption faint ${styles.privacy}`}><Lock size={16} />글은 나에게만 보여요. 우주 광장에는 내가 고른 한 줄만 나가요.</p>
      </aside>
      <Analyzing />
    </form>
  );
}

function Submit({ mode, label, style, disabled }: { mode: "keep" | "float"; label: string; style: string; disabled: boolean }) {
  const { pending } = useFormStatus();
  return <button name="mode" value={mode} className={`btn ${style}`} disabled={disabled || pending}>{label}</button>;
}

// Figma W-23: shown over the editor while the starlight prism reads the writing.
function Analyzing() {
  const { pending, data } = useFormStatus();
  if (!pending || data?.get("mode") !== "float") return null;
  return (
    <div className={styles.overlay} role="status" aria-live="polite">
      <div className={styles.prism} aria-hidden="true">
        <span /><span /><span />
        <StarFilled size={48} />
      </div>
      <p className="h2">별빛 프리즘이 마음의 결을 비추고 있어요</p>
      <p className="body-l muted">별의 깊이 · 빛의 선명함 · 마음의 무게를<br />부드럽게 살펴보는 중이에요.</p>
      <p className="caption faint"><Lock size={14} /> 쓴 글은 암호화되어 안전하게 보관돼요</p>
    </div>
  );
}
