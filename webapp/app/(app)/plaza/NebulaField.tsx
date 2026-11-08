"use client";

import Link from "next/link";
import { useState } from "react";
import { NebulaFigure } from "@/components/NebulaFigure";
import type { Dot } from "@/lib/nebula";
import type { PlazaNebula } from "@/lib/types";
import styles from "./plaza.module.css";

const W = 600, H = 420, BOX = 190;

function hash(s: string) {
  let h = 0;
  for (const c of s) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return h;
}

/** Spread the nebulae over the field: a loose grid with a steady jitter from each id. */
function layout(items: PlazaNebula[]) {
  const cols = Math.max(2, Math.ceil(Math.sqrt(items.length * 1.4)));
  const rows = Math.ceil(items.length / cols);
  const cw = W / cols, ch = H / Math.max(rows, 2);
  return items.map((n, i) => {
    const h = hash(n.id);
    const x = (i % cols) * cw + cw / 2 + ((h % 41) - 20) * (cw / 140);
    const y = Math.floor(i / cols) * ch + ch / 2 + (((h >> 6) % 41) - 20) * (ch / 140);
    return { n, x, y };
  });
}

// Figma W-44 성운 들판: nebulae spread over the sky; pick one to see its card, zoom with + and −.
export function NebulaField({ nebulae }: { nebulae: PlazaNebula[] }) {
  const [picked, setPicked] = useState(nebulae[0]?.id ?? null);
  const [zoom, setZoom] = useState(1);
  const placed = layout(nebulae);
  const sel = nebulae.find((n) => n.id === picked) ?? null;
  return (
    <div className={styles.fieldInner}>
      <div className={styles.zoom} role="group" aria-label="확대">
        <button type="button" onClick={() => setZoom((z) => Math.min(2.4, +(z + 0.4).toFixed(1)))} aria-label="확대">+</button>
        <span>{zoom}×</span>
        <button type="button" onClick={() => setZoom((z) => Math.max(1, +(z - 0.4).toFixed(1)))} aria-label="축소">−</button>
      </div>
      <div className={styles.viewport}>
        <svg viewBox={`0 0 ${W} ${H}`} width="100%" height="100%" style={{ transform: `scale(${zoom})`, transformOrigin: sel ? `${(placed.find((p) => p.n.id === sel.id)!.x / W) * 100}% ${(placed.find((p) => p.n.id === sel.id)!.y / H) * 100}%` : "center" }}>
          {placed.map(({ n, x, y }) => (
            <g key={n.id} transform={`translate(${x - BOX / 2} ${y - BOX / 2})`} onClick={() => setPicked(n.id)} style={{ cursor: "pointer" }}
              role="button" tabIndex={0} aria-label={n.name} aria-pressed={n.id === picked}
              onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") setPicked(n.id); }}>
              <rect width={BOX} height={BOX} fill="transparent" />
              {n.id === picked && <circle cx={BOX / 2} cy={BOX / 2} r={BOX / 2 - 2} fill="none" stroke="#fbbf24" strokeWidth={1.5} strokeDasharray="5 5" />}
              <svg width={BOX} height={BOX} viewBox="0 0 340 340">
                <NebulaFigure width={340} height={340} dotScale={2.2} label={n.name}
                  figure={{ silhouette: n.shape.silhouette, edges: n.shape.edges, dots: n.shape.stars.map((s): Dot => ({ mood: s.mood })) }} />
              </svg>
            </g>
          ))}
        </svg>
      </div>
      <p className="caption faint">성운을 눌러 고르고, + − 로 확대해 보세요</p>
      {sel && (
        <div className={`card ${styles.selected}`}>
          <div>
            <span className="label-m">{sel.name}</span>
            <span className={styles.tags}>
              <span className={styles.gold}>깊이 {sel.depth_level}단계</span>
              <span className={styles.violet}>{sel.resonated ? "공명했어요" : "공명"}</span>
            </span>
          </div>
          <Link href={`/plaza/nebulae/${sel.id}`} className={styles.enter}>들어가기 ›</Link>
        </div>
      )}
    </div>
  );
}
