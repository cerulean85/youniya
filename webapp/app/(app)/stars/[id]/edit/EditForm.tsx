"use client";

import Link from "next/link";
import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import { Info, Lock } from "@/components/icons";
import { MOODS } from "@/lib/format";
import type { Mood } from "@/lib/types";
import { editStar } from "../actions";
import styles from "../../../write/write.module.css";

export function EditForm({ id, moods: initial, title: t, body: b }: { id: string; moods: Mood[]; title: string; body: string }) {
  const [moods, setMoods] = useState<Mood[]>(initial);
  const toggleMood = (m: Mood) => setMoods((list) => (list.includes(m) ? (list.length > 1 ? list.filter((x) => x !== m) : list) : [...list, m]));
  const [title, setTitle] = useState(t);
  const [body, setBody] = useState(b);
  const [state, action] = useActionState(editStar.bind(null, id), null);
  return (
    <form action={action} className={styles.body}>
      <input type="hidden" name="moods" value={moods.join(",")} />
      <div className={`card ${styles.editor}`}>
        <div className={styles.moods} role="group" aria-label="오늘의 기분">
          {MOODS.map((m) => (
            <button key={m.key} type="button" aria-pressed={moods.includes(m.key)} className={styles.mood}
              style={{ ["--c" as string]: m.color }} onClick={() => toggleMood(m.key)}>{m.label}</button>
          ))}
        </div>
        <input name="title" className={`h1 ${styles.title}`} placeholder="제목 없는 별" value={title} maxLength={60}
          onChange={(e) => setTitle(e.target.value)} aria-label="제목" />
        <textarea name="body" className={`journal ${styles.text}`} value={body} maxLength={20000} required
          onChange={(e) => setBody(e.target.value)} aria-label="본문" />
        <div className={styles.footer}>
          <span className="caption faint">{body.trim().length.toLocaleString("ko-KR")}자</span>
          <span className={styles.spacer} />
          <Save disabled={!body.trim()} />
        </div>
      </div>
      <aside className={styles.side}>
        <div className={styles.banner}><Info size={18} />별빛 없는 별은 기분·제목·본문을 고칠 수 있어요. 별빛을 받으면 글이 잠겨요.</div>
        {state?.error && <div className={styles.error} role="alert">{state.error}</div>}
        <p className={`caption faint ${styles.privacy}`}><Lock size={16} />글은 나에게만 보여요. 우주 광장에는 내가 고른 한 줄만 나가요.</p>
        <Link href={`/stars/${id}`} className="btn btn-ghost">취소</Link>
      </aside>
    </form>
  );
}

function Save({ disabled }: { disabled: boolean }) {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary" disabled={disabled || pending}>{pending ? "저장하는 중…" : "저장"}</button>;
}
