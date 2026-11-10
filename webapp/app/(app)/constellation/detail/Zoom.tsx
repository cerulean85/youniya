"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { CANVAS, type Constellation } from "@/lib/constellation";
import { kst, moodOf } from "@/lib/format";
import { starLinks } from "./actions";
import styles from "./detail.module.css";

const W = 600, H = Math.round((600 * CANVAS.height) / CANVAS.width);

// Figma W-68 / W-69 (iOS 70·77 확대, ConstellationDetailView): zoom with + and −, pick a star to see it and
// its 별 잇기 (silver dotted lines to linked stars in this month, a count for the rest).
export function ConstellationZoom({ c }: { c: Constellation }) {
  const [zoom, setZoom] = useState(1);
  const [picked, setPicked] = useState<number | null>(null);
  const [links, setLinks] = useState<{ id: string; created_at: string }[]>([]);
  const [, start] = useTransition();
  const slot = picked == null ? null : c.slots[picked];
  const at = (i: number) => [c.slots[i].x * W, c.slots[i].y * H] as const;
  const indexOf = new Map(c.slots.filter((s) => s.star).map((s) => [s.star!.id, s.index]));
  const here = links.filter((l) => indexOf.has(l.id));
  const away = links.filter((l) => !indexOf.has(l.id));
  const awayMonths = [...new Set(away.map((l) => `${kst(l.created_at).m}월`))];

  const pick = (i: number) => {
    const s = c.slots[i].star;
    if (!s) return;
    setPicked(i);
    setLinks([]);
    start(async () => setLinks(await starLinks(s.id)));
  };

  // Zoom about the picked star (or the middle).
  const [cx, cy] = slot ? at(slot.index) : [W / 2, H / 2];
  const vw = W / zoom, vh = H / zoom;
  const vx = Math.min(Math.max(cx - vw / 2, 0), W - vw), vy = Math.min(Math.max(cy - vh / 2, 0), H - vh);

  return (
    <div className={styles.zoom}>
      <div className={styles.canvas}>
        <svg viewBox={`${vx} ${vy} ${vw} ${vh}`} role="img" aria-label={`${c.name}자리 · ${c.filled} / ${c.total} 자리 채움`}>
          {c.lines.map(([a, b]) => {
            const lit = !!(c.slots[a]?.star && c.slots[b]?.star);
            const [x1, y1] = at(a), [x2, y2] = at(b);
            return <line key={`${a}-${b}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke={lit ? "#fbbf24" : "#fff"} strokeOpacity={lit ? 0.45 : 0.14} strokeWidth={1.2 / zoom} strokeDasharray={lit ? undefined : `${3 / zoom} ${6 / zoom}`} />;
          })}
          {slot && here.map((l) => {
            const [x1, y1] = at(slot.index), [x2, y2] = at(indexOf.get(l.id)!);
            return <line key={l.id} x1={x1} y1={y1} x2={x2} y2={y2} stroke="#e2e8f0" strokeOpacity={0.7} strokeWidth={1.4 / zoom} strokeDasharray={`${2 / zoom} ${4 / zoom}`} />;
          })}
          {c.slots.map((s) => {
            const [x, y] = at(s.index);
            if (!s.star) return <circle key={s.index} cx={x} cy={y} r={6 / Math.sqrt(zoom)} fill="none" stroke="#fff" strokeOpacity={0.35} strokeWidth={1 / zoom} strokeDasharray={`${3 / zoom} ${3 / zoom}`} />;
            const color = moodOf(s.star.mood).color, lit = s.star.has_starlight !== false && s.star.starlight != null;
            const r = (lit ? 8 + ((s.star.starlight ?? 300) / 1000) * 5 : 5) / Math.sqrt(zoom);
            return (
              <g key={s.index} onClick={() => pick(s.index)} style={{ cursor: "pointer" }} role="button" aria-label={`${s.star.title || "제목 없는 별"} 고르기`}>
                {picked === s.index && <circle cx={x} cy={y} r={r * 2.2} fill="none" stroke="#fbbf24" strokeOpacity={0.6} strokeWidth={1 / zoom} strokeDasharray={`${2 / zoom} ${3 / zoom}`} />}
                <circle cx={x} cy={y} r={r} fill={color} opacity={lit ? 1 : 0.55} style={lit ? { filter: `drop-shadow(0 0 6px ${color})` } : undefined} />
              </g>
            );
          })}
        </svg>
        <div className={styles.controls} aria-label="확대">
          <button type="button" onClick={() => setZoom((z) => Math.min(3, +(z + 0.7).toFixed(1)))} aria-label="확대" disabled={zoom >= 3}>+</button>
          <span>{zoom.toFixed(1)}×</span>
          <button type="button" onClick={() => setZoom((z) => Math.max(1, +(z - 0.7).toFixed(1)))} aria-label="축소" disabled={zoom <= 1}>−</button>
        </div>
      </div>
      <p className="caption faint">{slot ? "별의 모양은 쓴 글의 결로 정해져요" : "+ − 로 확대 · 별을 눌러 보기"}</p>
      {slot?.star && (
        <div className={`card ${styles.picked}`}>
          <div>
            <span className="label-m">내 별 · {slot.star.title || "제목 없는 별"}</span>
            <span className="caption muted">
              {links.length === 0 ? "아직 이어진 별이 없어요" : `이어진 별 ${links.length}${here.length ? ` · 이번 달 ${here.length}개는 은빛 선으로 보여요` : ""}${away.length ? ` · ${awayMonths.join("·")} 별 ${away.length}개와도 이어져 있어요` : ""}`}
            </span>
          </div>
          <Link href={`/stars/${slot.star.id}`} className={styles.go}>별 보기 ›</Link>
        </div>
      )}
    </div>
  );
}
