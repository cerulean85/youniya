"use client";

import { useOptimistic, useRef, useState, useTransition } from "react";
import { useFormStatus } from "react-dom";
import { Bell, ChevronRight, Sparkle } from "@/components/icons";
import { SKIES, type Sky } from "@/lib/types";
import { deleteAccount, setMarketing, setReduceMotion, setSky, unblock, unshareAll, unshareOne } from "./actions";
import styles from "./settings.module.css";

function Switch({ icon, label, on, save }: { icon: React.ReactNode; label: string; on: boolean; save: (next: boolean) => Promise<void> }) {
  const [value, setValue] = useOptimistic(on);
  const [, start] = useTransition();
  return (
    <label className={styles.row}>
      {icon}<span>{label}</span>
      <input type="checkbox" role="switch" className={styles.switch} checked={value}
        onChange={(e) => { const next = e.target.checked; start(async () => { setValue(next); await save(next); }); }} />
    </label>
  );
}

export function MarketingToggle({ on }: { on: boolean }) {
  return <Switch icon={<Bell size={18} />} label="새 기능·혜택 알림" on={on} save={setMarketing} />;
}

/** 애니메이션 줄이기: <html data-motion> follows the account (ApplySky), on top of the OS setting. */
export function MotionToggle({ on }: { on: boolean }) {
  return <Switch icon={<Sparkle size={18} />} label="애니메이션 줄이기" on={on} save={async (next) => {
    const root = document.documentElement;
    if (next) root.dataset.motion = "reduce"; else delete root.dataset.motion;
    await setReduceMotion(next);
  }} />;
}

// W-82 차단한 별지기: when and where, never who (the API doesn't say who).
export function UnblockButton({ id }: { id: string }) {
  return <form action={unblock.bind(null, id)} className={styles.under}><Pending label="차단 풀기" busy="푸는 중…" style={styles.textButton} /></form>;
}

// W-77: each shared star can leave the plaza on its own.
export function UnshareButton({ starId }: { starId: string }) {
  return <form action={unshareOne.bind(null, starId)} className={styles.under}><Pending label="광장에서 거두기" busy="거두는 중…" style={styles.textButton} /></form>;
}

export function DangerZone({ part, shared, icon }: { part: "unshare" | "delete"; shared: number; icon: React.ReactNode }) {
  const dialog = useRef<HTMLDialogElement>(null);
  if (part === "unshare") return (
    <>
      <button type="button" className={styles.row} onClick={() => dialog.current?.showModal()} disabled={shared === 0}>
        {icon}<span>모든 공유 거두기</span><span className={styles.value}><ChevronRight size={16} /></span>
      </button>
      <dialog ref={dialog} className={`card ${styles.dialog}`} aria-labelledby="unshare-title">
        <form action={async () => { await unshareAll(); dialog.current?.close(); }}>
          <h2 id="unshare-title" className="h2">나눈 별을 모두 거둘까요?</h2>
          <p className="body-s muted">우주 광장에 나눈 별 {shared}개가 모두 내려가요. 이미 받은 공명과 별빛 한 줄은 그대로 남아요.</p>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => dialog.current?.close()}>취소</button>
            <Pending label="모두 거두기" busy="거두는 중…" style="btn btn-primary" />
          </div>
        </form>
      </dialog>
    </>
  );
  return (
    <>
      <button type="button" className={`${styles.row} ${styles.danger}`} onClick={() => dialog.current?.showModal()}>
        {icon}<span>계정 영구 삭제</span><span className={styles.value}><ChevronRight size={16} /></span>
      </button>
      <dialog ref={dialog} className={`card ${styles.dialog}`} aria-labelledby="delete-title">
        <form action={deleteAccount}>
          <h2 id="delete-title" className="h2">계정을 영구 삭제할까요?</h2>
          <p className="body-s muted">모든 별과 별빛, 별자리, 나눈 별과 받은 별빛 한 줄, 남은 코인이 사라지고 되살릴 수 없어요. 결제 기록만 법에 따라 5년 동안 보관해요.</p>
          <label className={styles.confirm}>
            <span className="caption muted">확인을 위해 &lsquo;삭제&rsquo;라고 적어 주세요</span>
            <input name="confirm" autoComplete="off" required pattern="삭제" />
          </label>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => dialog.current?.close()}>취소</button>
            <Pending label="영구 삭제" busy="삭제하는 중…" style={`btn ${styles.dangerButton}`} />
          </div>
        </form>
      </dialog>
    </>
  );
}

function Pending({ label, busy, style }: { label: string; busy: string; style: string }) {
  const { pending } = useFormStatus();
  return <button className={style} disabled={pending}>{pending ? busy : label}</button>;
}

// Figma W-90 (iOS 68, 기획서 14.7): a card per sky; members see the membership ones too.
export function SkyCards({ sky, member }: { sky: Sky; member: boolean }) {
  const [value, setValue] = useOptimistic(sky);
  const [error, setError] = useState<string | null>(null);
  const [, start] = useTransition();
  return (
    <div className={styles.skyCards} role="radiogroup" aria-label="우주의 색">
      {SKIES.filter((s) => member || !s.member || s.key === sky).map((s) => (
        <button key={s.key} type="button" role="radio" aria-checked={value === s.key} className={styles.skyCard}
          onClick={() => start(async () => {
            setError(null); setValue(s.key);
            const r = await setSky(s.key);
            if (r?.error) setError(r.error);
          })}>
          <span className={styles.swatch} style={{ ["--a" as string]: s.glows[0], ["--b" as string]: s.glows[1], ["--c" as string]: s.glows[2] }} aria-hidden="true" />
          <span className={styles.skyText}><span className="label-m">{s.label}</span><span className="caption faint">{s.detail}</span></span>
          <span className={styles.radio} aria-hidden="true" />
        </button>
      ))}
      {error && <p className="caption" role="alert" style={{ color: "var(--anger)" }}>{error}</p>}
    </div>
  );
}
