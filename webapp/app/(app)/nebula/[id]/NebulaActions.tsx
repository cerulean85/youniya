"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { useFormStatus } from "react-dom";
import { polishStory, shareNebula, unshareNebula } from "../actions";
import styles from "./nebula-detail.module.css";

export function PolishButton({ id, free, cost, coins }: { id: string; free: boolean; cost: number; coins: number }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<{ error?: string; code?: string } | null>(null);
  return (
    <div className={styles.polish}>
      <button type="button" className="btn btn-secondary" disabled={pending}
        onClick={() => start(async () => setError((await polishStory(id)) ?? null))}>
        {pending ? "다듬는 중…" : free ? "서사 다듬기 · 처음 1번 무료" : `서사 다듬기 · ${cost}코인`}
      </button>
      {!free && <span className="caption faint">보유 {coins}코인</span>}
      {error?.error && <span className="body-s" role="alert">{error.error} {error.code === "insufficient_coins" && <Link href="/coins" className={styles.link}>코인 충전하기</Link>}</span>}
    </div>
  );
}

// 71 하늘에 띄우기: the nebula's shape goes to the plaza; others may leave a 별빛 한 줄 if allowed.
export function ShareNebula({ id, shared }: { id: string; shared: boolean }) {
  if (shared) {
    return (
      <form action={unshareNebula.bind(null, id)} className={`card ${styles.share}`}>
        <span className="label-m">하늘에 띄운 성운이에요</span>
        <span className="body-s muted">우주 광장에 모양과 색, 이름만 보여요. 글과 날짜는 나가지 않아요.</span>
        <Submit label="광장에서 거두기" busy="거두는 중…" style="btn-ghost" />
      </form>
    );
  }
  return (
    <form action={shareNebula.bind(null, id)} className={`card ${styles.share}`}>
      <span className="label-m">우주 광장에 띄워 볼까요?</span>
      <span className="body-s muted">모양과 색, 이름만 나가요. 글과 날짜, 계정은 나가지 않아요.</span>
      <label className={styles.check}><input type="checkbox" name="receive_lines" defaultChecked />다른 별지기의 별빛 한 줄 받기</label>
      <Submit label="하늘에 띄우기" busy="띄우는 중…" style="btn-primary" />
    </form>
  );
}

function Submit({ label, busy, style }: { label: string; busy: string; style: string }) {
  const { pending } = useFormStatus();
  return <button className={`btn ${style}`} disabled={pending}>{pending ? busy : label}</button>;
}
