"use client";

import { useState } from "react";
import type { Analysis } from "@/lib/types";
import styles from "./StarlightReading.module.css";

const MEASURES = [
  { key: "depth", label: "별의 깊이", max: 400, color: "var(--primary)" },
  { key: "clarity", label: "빛의 선명함", max: 300, color: "var(--cyan)" },
  { key: "weight", label: "마음의 무게", max: 300, color: "var(--pink)" },
] as const;

/** "prism-v1-2026-11" → { name: "v1", month: "2026년 11월" }; without a version, the month the star was read. */
function method(version: string | null | undefined, readAt: string) {
  const m = version?.match(/^prism-(v\d+)-(\d{4})-(\d{2})$/);
  const [name, y, mo] = m ? [m[1], m[2], m[3]] : ["v1", readAt.slice(0, 4), readAt.slice(5, 7)];
  return { name, month: `${y}년 ${Number(mo)}월` };
}

// Figma W-48 (별빛 풀이 펼침, 기획서 17.3): the three measures with their reasons and an overall reading.
// Folded on star detail, open on the result screen (`open`). `animate` staggers the lines (17.4).
export function StarlightReading({ analysis, readAt, version, open: startOpen = false, animate = false }: { analysis: Analysis; readAt: string; version?: string | null; open?: boolean; animate?: boolean }) {
  const how = method(version, readAt);
  const [open, setOpen] = useState(startOpen);
  const scores = analysis.scores;
  let line = 0;
  const step = () => (animate ? { ["--i" as string]: line++ } : undefined);
  return (
    <div className={styles.wrap} data-animate={animate}>
      {open && (
        <section className={`card ${styles.card}`} aria-label="별빛 풀이">
          <h3 className="h3" style={step()} data-line>별빛 {analysis.starlight}는 이렇게 모였어요</h3>
          {MEASURES.map((m) => {
            const v = scores?.[m.key] ?? Math.round((analysis[m.key] ?? 0) * m.max);
            const reason = analysis[`${m.key}_reason`];
            return (
              <div key={m.key} className={styles.measure} style={step()} data-line>
                <div className={styles.head}><span className="label-m">{m.label}</span><span className="label-s muted">{v} / {m.max}</span></div>
                <i style={{ ["--v" as string]: `${Math.min(100, (v / m.max) * 100)}%`, ["--c" as string]: m.color }} />
                {reason && <p className="body-s muted">{reason}</p>}
              </div>
            );
          })}
          {analysis.interpretation && (
            <div className={styles.overall} style={step()} data-line>
              <span className="label-m">종합 해석</span>
              <p className="journal">{analysis.interpretation}</p>
            </div>
          )}
          <p className="caption faint" style={step()} data-line>점수는 글을 평가한 것이 아니라, 이 글에서 마음이 어디까지 닿았는지를 별빛으로 옮긴 거예요.</p>
          <p className="caption faint" style={step()} data-line>별빛 프리즘 {how.name} · {how.month} 방식으로 읽었어요</p>
        </section>
      )}
      <button type="button" className={styles.toggle} aria-expanded={open} onClick={() => setOpen(!open)}>
        {open ? "별빛 풀이 접기 ▴" : "별빛 풀이 보기 ▾"}
      </button>
    </div>
  );
}
