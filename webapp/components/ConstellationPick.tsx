"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { starLinks } from "@/app/(app)/constellation/actions";
import { CANVAS, type Constellation } from "@/lib/constellation";
import { kst, moodOf } from "@/lib/format";
import styles from "./ConstellationPick.module.css";

const W = 600, H = Math.round((600 * CANVAS.height) / CANVAS.width);

// Figma W-16-1 (기획서 23장): pressing a star on W-16 rings it, shows its 별 잇기 in this month as silver dotted
// lines, and a card under the figure: 내 별 · 제목, 이어진 별, 별 보기 ›. No zoom and no table (W-68/W-69 are gone).
export function ConstellationPick({ c }: { c: Constellation }) {
  const [picked, setPicked] = useState<number | null>(null);
  const [links, setLinks] = useState<{ id: string; created_at: string }[] | null>(null);
  const [, start] = useTransition();
  const slot = picked == null ? null : c.slots[picked];
  const at = (i: number) => [c.slots[i].x * W, c.slots[i].y * H] as const;
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
    <div className={styles.wrap}>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" height="100%" role="img" aria-label={`${c.name}자리 · ${c.filled} / ${c.total} 자리 채움`}>
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
          if (!s.star) return <circle key={s.index} cx={x} cy={y} r={6} fill="none" stroke="#fff" strokeOpacity={0.35} strokeWidth={1} strokeDasharray="3 3" />;
          const color = moodOf(s.star.mood).color, lit = s.star.has_starlight !== false && s.star.starlight != null;
          const r = lit ? 8 + ((s.star.starlight ?? 300) / 1000) * 5 : 5;
          return (
            <g key={s.index} className={styles.star} onClick={() => pick(s.index)} role="button" tabIndex={0} aria-pressed={picked === s.index}
              aria-label={`${s.star.title || "제목 없는 별"} 고르기`} onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); pick(s.index); } }}>
              <circle cx={x} cy={y} r={r + 10} fill="transparent" />
              {picked === s.index && <circle cx={x} cy={y} r={r * 2} fill="none" stroke="#fbbf24" strokeOpacity={0.7} strokeWidth={1} strokeDasharray="2 3" />}
              <circle cx={x} cy={y} r={r} fill={color} opacity={lit ? 1 : 0.55} style={lit ? { filter: `drop-shadow(0 0 6px ${color})` } : undefined} />
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
