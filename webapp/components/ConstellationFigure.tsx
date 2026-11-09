import Link from "next/link";
import { CANVAS, type Constellation } from "@/lib/constellation";
import { moodOf } from "@/lib/format";

// 기획서 16장: filled slots are stars in their mood colour (starlight sets size and glow; a star without
// starlight is small and faint), empty slots stay as faint dashed rings, a line is gold only when both
// ends are filled, and stars beyond the slots float faintly around the figure. No 별 잇기 lines here.
export function ConstellationFigure({ c, width = 600, height = Math.round((600 * CANVAS.height) / CANVAS.width), links = true }: { c: Constellation; width?: number; height?: number; links?: boolean }) {
  const k = width / 600;
  const at = (i: number) => [c.slots[i].x * width, c.slots[i].y * height] as const;
  const extra = c.extra.map((s, i) => {
    const a = (i * 2.39996) % (Math.PI * 2), r = 0.42 + (i % 3) * 0.03;
    return { s, x: width / 2 + Math.cos(a) * width * r, y: height / 2 + Math.sin(a) * height * r };
  });
  return (
    <svg viewBox={`0 0 ${width} ${height}`} width="100%" height="100%" role="img" aria-label={`${c.name}자리 · ${c.filled} / ${c.total} 자리 채움`}>
      {c.lines.map(([a, b]) => {
        const lit = !!(c.slots[a]?.star && c.slots[b]?.star);
        const [x1, y1] = at(a), [x2, y2] = at(b);
        return <line key={`${a}-${b}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke={lit ? "#fbbf24" : "#ffffff"} strokeOpacity={lit ? 0.45 : 0.14} strokeWidth={1.2 * k} strokeDasharray={lit ? undefined : `${3 * k} ${6 * k}`} />;
      })}
      {extra.map(({ s, x, y }) => <circle key={s.id} cx={x} cy={y} r={3 * k} fill={moodOf(s.mood).color} opacity={0.35} />)}
      {c.slots.map((slot) => {
        const [x, y] = at(slot.index);
        if (!slot.star) return <circle key={slot.index} cx={x} cy={y} r={6 * k} fill="none" stroke="#ffffff" strokeOpacity={0.35} strokeWidth={k} strokeDasharray={`${3 * k} ${3 * k}`} />;
        const s = slot.star, color = moodOf(s.mood).color, lit = s.has_starlight !== false && s.starlight != null;
        const r = (lit ? 8 + ((s.starlight ?? 300) / 1000) * 5 : 5) * k;
        const dot = <circle cx={x} cy={y} r={r} fill={color} opacity={lit ? 1 : 0.55} style={lit ? { filter: `drop-shadow(0 0 ${6 * k}px ${color})` } : undefined}><title>{`${s.title || "제목 없는 별"}${lit ? ` · ${s.starlight} 별빛` : " · 별빛 없는 별"}`}</title></circle>;
        return links ? <Link key={slot.index} href={`/stars/${s.id}`} prefetch={false}>{dot}</Link> : <g key={slot.index}>{dot}</g>;
      })}
    </svg>
  );
}
