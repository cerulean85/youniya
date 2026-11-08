"use client";

import { useFormStatus } from "react-dom";
import { shareNebula, unshareNebula } from "../actions";
import styles from "./nebula-detail.module.css";

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
