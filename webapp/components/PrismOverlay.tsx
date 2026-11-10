"use client";

import { useEffect, useRef, useState } from "react";
import { useFormStatus } from "react-dom";
import { Lock, StarFilled } from "./icons";
import styles from "./PrismOverlay.module.css";

const LONG_MS = 8000; // Figma W-104: past 8 s the screen says it is taking long and offers 그만두기.
const GIVE_UP_MS = 60_000; // The API answers within 55 s; with nothing by 60 s the browser cancels the attempt itself.

/** A new attempt id on the submit button's form, set as it is pressed (before the form data is read). */
export function freshAttempt(e: React.MouseEvent<HTMLButtonElement>) {
  const input = e.currentTarget.form?.elements.namedItem("attempt_id");
  if (input instanceof HTMLInputElement) input.value = crypto.randomUUID();
}

/** The hidden field freshAttempt fills; the server saves the star before the prism reads it, so it can be cancelled. */
export function AttemptField() {
  return <input type="hidden" name="attempt_id" defaultValue="" />;
}

// Figma W-23: shown over the page while the starlight prism reads the writing. Sits inside the form;
// `mode` limits it to submissions with that mode (writing has a keep button that doesn't read anything).
// With an attempt id in the form (AttemptField) it adds W-104/W-105: after 8 s, 그만두기 leaves the star without
// starlight and charges nothing (POST /v1/starlight/attempts/{id}/cancel, through /starlight/{attempt}/cancel).
export function PrismOverlay({ mode, title, body }: { mode?: string; title?: string; body?: React.ReactNode }) {
  const { pending, data } = useFormStatus();
  if (!pending || (mode && data?.get("mode") !== mode)) return null;
  const attempt = data?.get("attempt_id");
  return <Reading title={title} body={body} stop={typeof attempt === "string" && attempt ? attempt : undefined} />;
}

function Reading({ title, body, stop }: { title?: string; body?: React.ReactNode; stop?: string }) {
  const [long, setLong] = useState(false);
  const [stopping, setStopping] = useState(false);
  const [failed, setFailed] = useState(false);
  const quit = async () => {
    if (!stop) return;
    setStopping(true); setFailed(false);
    const res = await fetch(`/starlight/${encodeURIComponent(stop)}/cancel`, { method: "POST" }).catch(() => null);
    const r = res?.ok ? await res.json().catch(() => null) as { to?: string } | null : null;
    // A full load also drops the request still waiting for the prism (its late answer is 409 starlight_cancelled).
    if (r?.to) { window.location.assign(r.to); return; }
    setStopping(false); setFailed(true);
  };
  const quitRef = useRef(quit);
  useEffect(() => { quitRef.current = quit; });
  useEffect(() => {
    const long = setTimeout(() => setLong(true), LONG_MS);
    const giveUp = setTimeout(() => { void quitRef.current(); }, GIVE_UP_MS);
    return () => { clearTimeout(long); clearTimeout(giveUp); };
  }, []);

  const offer = long && stop;
  return (
    <div className={styles.overlay} role="status" aria-live="polite">
      <div className={styles.prism} aria-hidden="true">
        <span /><span /><span />
        <StarFilled size={48} />
      </div>
      <p className="h2">{offer ? "조금 오래 걸리고 있어요" : title ?? "별빛 프리즘이 마음의 결을 비추고 있어요"}</p>
      <p className="body-l muted">{offer ? <>기다리지 않아도 괜찮아요. 그만두면 별빛 없이 띄워 두고,<br />오늘 무료와 코인은 쓰지 않아요.</>
        : body ?? <>별의 깊이 · 빛의 선명함 · 마음의 무게를<br />부드럽게 살펴보는 중이에요.</>}</p>
      {offer && <button type="button" className={`btn btn-ghost ${styles.stop}`} onClick={quit} disabled={stopping}>{stopping ? "그만두는 중…" : "그만두기"}</button>}
      {failed && <p className="caption" role="alert" style={{ color: "var(--anger)" }}>지금은 그만둘 수 없어요. 조금만 더 기다려 주세요.</p>}
      <p className={`caption faint ${styles.note}`}><Lock size={14} /> 쓴 글은 암호화되어 안전하게 보관돼요</p>
    </div>
  );
}
