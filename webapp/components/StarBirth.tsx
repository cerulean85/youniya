"use client";

import { useEffect, useState } from "react";
import { starPoints } from "./StarGlyph";
import styles from "./StarBirth.module.css";

const TITLES = ["마음을 모으는 중", "빛이 번져요", "별이 모양을 이뤄요", "별이 떴어요"];
const AT = [600, 1200, 1700]; // ms: Mobile 61–64, the same four scenes in 1.7 s

const still = () => document.documentElement.dataset.motion === "reduce" || matchMedia("(prefers-reduced-motion: reduce)").matches;

// Figma W-102: right after a star is floated, four scenes over the whole screen (the sidebar dims under it).
// Esc or a click jumps to the last scene; reduced motion shows only that one. Once per star in this tab.
// A star without starlight ends small and faint in its mood's colour. A lit star (Mobile 61-1, 기획서 20장) takes its own
// shape in its first mood's colour: faint in the third scene, settled and clear in the fourth.
export function StarBirth({ id, unlit, shape, color }: { id: string; unlit?: string; shape?: { points: number; sharpness: string } | null; color?: string }) {
  const [phase, setPhase] = useState<number | null>(null);

  useEffect(() => {
    const key = `yn_born_${id}`;
    try { if (sessionStorage.getItem(key)) return; } catch { /* private mode */ }
    const timers: number[] = [];
    const start = window.setTimeout(() => {
      try { sessionStorage.setItem(key, "1"); } catch { /* private mode */ }
      if (still()) { setPhase(3); return; }
      setPhase(0);
      AT.forEach((ms, i) => timers.push(window.setTimeout(() => setPhase(i + 1), ms)));
    }, 0);
    return () => { clearTimeout(start); timers.forEach(clearTimeout); };
  }, [id]);

  useEffect(() => {
    if (phase == null) return;
    const key = (e: KeyboardEvent) => { if (e.key === "Escape") setPhase((p) => (p === 3 ? null : 3)); };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [phase]);

  if (phase == null) return null;
  const done = phase === 3;
  return (
    <div className={styles.overlay} data-phase={phase} data-unlit={unlit ? "" : undefined} data-shaped={!unlit && shape ? "" : undefined}
      style={unlit ? { ["--core" as string]: unlit } : color ? { ["--mood" as string]: color } : undefined}
      role="dialog" aria-modal="true" aria-label="별 탄생" onClick={() => !done && setPhase(3)}>
      <h2 className="h2" aria-live="polite">{TITLES[phase]}</h2>
      <div className={styles.stage} aria-hidden="true">
        <span className={styles.halo} />
        <span className={styles.core} />
        {!unlit && shape && (
          <svg className={styles.shape} viewBox="0 0 100 100">
            <polygon points={starPoints(shape.points, shape.sharpness)} strokeLinejoin="round" />
            <circle cx="50" cy="50" r="7" />
          </svg>
        )}
        {done && <><i className={styles.sparkA} /><i className={styles.sparkB} /></>}
      </div>
      <button type="button" className={`btn btn-primary ${styles.show}`} disabled={!done} onClick={() => setPhase(null)}>별 보기</button>
    </div>
  );
}
