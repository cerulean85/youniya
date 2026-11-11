"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { starLinks } from "@/app/(app)/constellation/actions";
import { starPoints } from "@/components/StarGlyph";
import { CANVAS, type Constellation } from "@/lib/constellation";
import { kst, moodOf } from "@/lib/format";
import styles from "./ConstellationPick.module.css";

const W = 600, H = Math.round((600 * CANVAS.height) / CANVAS.width);

// Figma W-16-1 (기획서 23장): pressing a star on W-16 rings it, shows its 별 잇기 in this month as silver dotted
// lines, and a card under the figure: 내 별 · 제목, 이어진 별, 별 보기 ›. No zoom and no table (W-68/W-69 are gone).
type Shape = { points: number; sharpness: string } | null;
const MOODS = ["calm", "sorrow", "anger", "insight"] as const;

// Web 시안 v2 (591:28041): each filled slot is its star's own shape in its first mood's colour, sized by its
// starlight, with its date under it; a star without starlight is a small faint light. `shapes` fills in for
// servers whose constellation doesn't carry them.
// `still`: a picture only (no picking, no dates), as on 별자리 이야기.
export function ConstellationPick({ c, shapes, still = false }: { c: Constellation; shapes?: Map<string, Shape>; still?: boolean }) {
  const [picked, setPicked] = useState<number | null>(null);
  const [links, setLinks] = useState<{ id: string; created_at: string }[] | null>(null);
  const [, start] = useTransition();
  const slot = picked == null ? null : c.slots[picked];
  const at = (i: number) => [c.slots[i].x * W, c.slots[i].y * H] as const;
  // Framed to the figure's own stars (as the design frames each constellation), with room for shapes and dates.
  const xs = c.slots.map((sl) => sl.x * W), ys = c.slots.map((sl) => sl.y * H), m = 56;
  const box = { x: Math.min(...xs) - m, y: Math.min(...ys) - m, w: Math.max(...xs) - Math.min(...xs) + m * 2, h: Math.max(...ys) - Math.min(...ys) + m * 2 };
  const indexOf = new Map(c.slots.filter((s) => s.star).map((s) => [s.star!.id, s.index]));
  const here = (links ?? []).filter((l) => indexOf.has(l.id));
  const away = (links ?? []).filter((l) => !indexOf.has(l.id));
  const awayMonths = [...new Set(away.map((l) => `${kst(l.created_at).m}월`))];
  const extra = c.extra.map((s, i) => {
    const a = (i * 2.39996) % (Math.PI * 2), r = 0.42 + (i % 3) * 0.03;
    // Rounded: the server's and the browser's trigonometry can differ in the last digit (hydration).
    return { s, x: Math.round((W / 2 + Math.cos(a) * W * r) * 10) / 10, y: Math.round((H / 2 + Math.sin(a) * H * r) * 10) / 10 };
  });

  const pick = (i: number) => {
    const s = c.slots[i].star;
    if (!s) return;
    if (picked === i) { setPicked(null); return; }
    setPicked(i);
    setLinks(null);
    start(async () => setLinks(await starLinks(s.id).catch(() => [])));
  };

  return (
    <div className={styles.wrap} style={{ ["--ar" as string]: `${box.w.toFixed(1)} / ${box.h.toFixed(1)}`, ["--arn" as string]: (box.w / box.h).toFixed(3) }}>
      <svg viewBox={`${box.x.toFixed(1)} ${box.y.toFixed(1)} ${box.w.toFixed(1)} ${box.h.toFixed(1)}`} width="100%" height="100%" role="img" aria-label={`${c.name}자리 · ${c.filled} / ${c.total} 자리 채움`} style={{ overflow: "visible" }}>
        <defs>
          {MOODS.map((m) => (
            <g key={m}>
              <radialGradient id={`cp-fill-${m}`} cx="50%" cy="50%" r="50%">
                <stop offset="0" stopColor="#fff" stopOpacity={0.95} /><stop offset="0.35" stopColor={moodOf(m).color} stopOpacity={0.95} /><stop offset="1" stopColor={moodOf(m).color} stopOpacity={0.78} />
              </radialGradient>
              <radialGradient id={`cp-glow-${m}`}><stop offset="0" stopColor={moodOf(m).color} stopOpacity={0.28} /><stop offset="1" stopColor={moodOf(m).color} stopOpacity={0} /></radialGradient>
            </g>
          ))}
        </defs>
        {c.lines.map(([a, b]) => {
          const lit = !!(c.slots[a]?.star && c.slots[b]?.star);
          const [x1, y1] = at(a), [x2, y2] = at(b);
          return <line key={`${a}-${b}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke={lit ? "#fbbf24" : "#fff"} strokeOpacity={lit ? 0.45 : 0.14} strokeWidth={1.2} strokeDasharray={lit ? undefined : "3 6"} />;
        })}
        {slot && here.map((l) => {
          const [x1, y1] = at(slot.index), [x2, y2] = at(indexOf.get(l.id)!);
          return <line key={l.id} className={styles.silver} x1={x1} y1={y1} x2={x2} y2={y2} stroke="#e2e8f0" strokeOpacity={0.75} strokeWidth={1.4} strokeDasharray="2 4" />;
        })}
        {extra.map(({ s, x, y }) => <circle key={s.id} cx={x} cy={y} r={3} fill={moodOf(s.mood).color} opacity={0.35} />)}
        {c.slots.map((s) => {
          const [x, y] = at(s.index);
          if (!s.star) return <circle key={s.index} cx={x} cy={y} r={7} fill="none" stroke="#fff" strokeOpacity={0.35} strokeWidth={1} strokeDasharray="3 3" />;
          const color = moodOf(s.star.mood).color, lit = s.star.has_starlight !== false && s.star.starlight != null;
          const shape = s.star.shape !== undefined ? s.star.shape : shapes?.get(s.star.id) ?? null;
          const size = lit ? 46 + ((s.star.starlight ?? 300) / 1000) * 30 : 12; // in the 600-wide canvas
          const day = `${kst(s.star.created_at).m}/${kst(s.star.created_at).d}`;
          return (
            <g key={s.index} {...(still ? {} : { className: styles.star, onClick: () => pick(s.index), role: "button", tabIndex: 0, "aria-pressed": picked === s.index,
              "aria-label": `${s.star.title || "제목 없는 별"} 고르기`, onKeyDown: (e: React.KeyboardEvent) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); pick(s.index); } } })}>
              <circle cx={x} cy={y} r={size / 2 + 8} fill={`url(#cp-glow-${s.star.mood})`} />
              {picked === s.index && <circle cx={x} cy={y} r={size * 0.72 + 6} fill="none" stroke="#fbbf24" strokeOpacity={0.7} strokeWidth={1} strokeDasharray="2 3" />}
              {lit ? (
                <g className="v2-twinkle" style={{ transformOrigin: `${x}px ${y}px`, filter: `drop-shadow(0 0 6px ${color})` }}>
                  <polygon transform={`translate(${x - size / 2} ${y - size / 2}) scale(${size / 100})`} points={starPoints(shape?.points ?? 5, shape?.sharpness ?? "normal")}
                    fill={`url(#cp-fill-${s.star.mood})`} stroke="#fff" strokeOpacity={0.55} strokeWidth={1.5 * 100 / size} strokeLinejoin="round" />
                  <circle cx={x} cy={y} r={size * 0.07} fill="#fff" opacity={0.92} />
                </g>
              ) : <circle cx={x} cy={y} r={6} fill={color} opacity={0.6} />}
              {!still && <text x={x} y={y + (lit ? size / 2 + 16 : 20)} textAnchor="middle" className={styles.date}>{day}</text>}
            </g>
          );
        })}
      </svg>
      {slot?.star && (
        <div className={styles.picked} role="status">
          <div>
            <span className="label-m">내 별 · {slot.star.title || "제목 없는 별"}</span>
            <span className="caption muted">
              {links == null ? "이어진 별을 살펴보는 중…" : links.length === 0 ? "아직 이어진 별이 없어요"
                : `이어진 별 ${links.length}${here.length ? ` · 이번 달 ${here.length}개는 은빛 선으로 보여요` : ""}${away.length ? ` · ${awayMonths.join("·")} 별 ${away.length}개와도 이어져 있어요` : ""}`}
            </span>
          </div>
          <Link href={`/stars/${slot.star.id}`} className={styles.go}>별 보기 ›</Link>
        </div>
      )}
    </div>
  );
}
