import { moodOf } from "@/lib/format";
import type { Mood } from "@/lib/types";

// A star drawn from the prism's shape: `points` tips, inner radius from sharpness, coloured by mood.
const INNER: Record<string, number> = { soft: 0.62, normal: 0.48, sharp: 0.32 };

/** The polygon's points in a 100×100 box: `points` tips, the inner radius from sharpness. */
export function starPoints(points = 5, sharpness = "normal") {
  const n = Math.max(3, Math.min(points, 12));
  const inner = INNER[sharpness] ?? INNER.normal;
  return Array.from({ length: n * 2 }, (_, i) => {
    const r = i % 2 === 0 ? 46 : 46 * inner;
    const a = (Math.PI * i) / n - Math.PI / 2;
    return `${(50 + r * Math.cos(a)).toFixed(1)},${(50 + r * Math.sin(a)).toFixed(1)}`;
  }).join(" ");
}

export function StarGlyph({ points = 5, sharpness = "normal", mood, size = 72 }: { points?: number; sharpness?: string; mood: Mood; size?: number }) {
  const d = starPoints(points, sharpness);
  const color = moodOf(mood).color;
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden="true" style={{ filter: `drop-shadow(0 0 ${size / 6}px ${color})` }}>
      <polygon points={d} fill={color} stroke="#fff" strokeOpacity={0.5} strokeWidth={1.5} strokeLinejoin="round" />
      <circle cx="50" cy="50" r="7" fill="#fff" opacity={0.85} />
    </svg>
  );
}
