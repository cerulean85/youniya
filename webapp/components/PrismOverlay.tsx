"use client";

import { useEffect, useState } from "react";
import { useFormStatus } from "react-dom";
import { Lock, StarFilled } from "./icons";
import styles from "./PrismOverlay.module.css";

const LONG_MS = 8000; // Figma W-104: past 8 s the screen says it is taking long and offers 그만두기.

// Figma W-23: shown over the page while the starlight prism reads the writing. Sits inside the form;
// `mode` limits it to submissions with that mode (writing has a keep button that doesn't read anything).
// `stop` (a star id) adds W-104/W-105: after 8 s, 그만두기 floats the star without starlight and charges nothing.
export function PrismOverlay({ mode, title, body, stop }: { mode?: string; title?: string; body?: React.ReactNode; stop?: string }) {
  const { pending, data } = useFormStatus();
  if (!pending || (mode && data?.get("mode") !== mode)) return null;
  return <Reading title={title} body={body} stop={stop} />;
}

function Reading({ title, body, stop }: { title?: string; body?: React.ReactNode; stop?: string }) {
  const [long, setLong] = useState(false);
  const [stopping, setStopping] = useState(false);
  const [failed, setFailed] = useState(false);
  useEffect(() => { const t = setTimeout(() => setLong(true), LONG_MS); return () => clearTimeout(t); }, []);
  const quit = async () => {
    if (!stop) return;
    setStopping(true); setFailed(false);
    const res = await fetch(`/stars/${stop}/stop`, { method: "POST" }).catch(() => null);
    // A full navigation also drops the request still waiting for the prism.
    // eslint-disable-next-line @next/next/no-location-assign-relative-destination -- a full load is what stops the pending action
    if (res?.ok) { window.location.assign(`/stars/${stop}?stopped=1`); return; }
    setStopping(false); setFailed(true);
  };
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
