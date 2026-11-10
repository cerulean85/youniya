"use client";

import { useFormStatus } from "react-dom";
import { Lock, StarFilled } from "./icons";
import styles from "./PrismOverlay.module.css";

// Figma W-23: shown over the page while the starlight prism reads the writing. Sits inside the form;
// `mode` limits it to submissions with that mode (writing has a keep button that doesn't read anything).
export function PrismOverlay({ mode, title, body }: { mode?: string; title?: string; body?: React.ReactNode }) {
  const { pending, data } = useFormStatus();
  if (!pending || (mode && data?.get("mode") !== mode)) return null;
  return (
    <div className={styles.overlay} role="status" aria-live="polite">
      <div className={styles.prism} aria-hidden="true">
        <span /><span /><span />
        <StarFilled size={48} />
      </div>
      <p className="h2">{title ?? "별빛 프리즘이 마음의 결을 비추고 있어요"}</p>
      <p className="body-l muted">{body ?? <>별의 깊이 · 빛의 선명함 · 마음의 무게를<br />부드럽게 살펴보는 중이에요.</>}</p>
      <p className={`caption faint ${styles.note}`}><Lock size={14} /> 쓴 글은 암호화되어 안전하게 보관돼요</p>
    </div>
  );
}
