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

// Figma Star/Shape (as the star cards draw it): a white core into the mood colour, a light rim, a soft halo.
// `twinkle` breathes slowly (stops with 동작 줄이기).
export function StarGlyph({ points = 5, sharpness = "normal", mood, size = 72, twinkle = false }: { points?: number; sharpness?: string; mood: Mood; size?: number; twinkle?: boolean }) {
  const d = starPoints(points, sharpness);
  const color = moodOf(mood).color;
  const id = `sg-${mood}`; // the same gradient for every star of a mood, so repeats are harmless
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden="true" className={twinkle ? "v2-twinkle" : undefined}
      style={{ filter: `drop-shadow(0 0 ${Math.max(4, size / 6)}px ${color})`, overflow: "visible" }}>
      <defs>
        <radialGradient id={id} cx="50%" cy="50%" r="50%">
          <stop offset="0" stopColor="#fff" stopOpacity={0.95} />
          <stop offset="0.35" stopColor={color} stopOpacity={0.95} />
          <stop offset="1" stopColor={color} stopOpacity={0.78} />
        </radialGradient>
      </defs>
      <polygon points={d} fill={`url(#${id})`} stroke="#fff" strokeOpacity={0.55} strokeWidth={1.5} strokeLinejoin="round" />
      <circle cx="50" cy="50" r="7" fill="#fff" opacity={0.92} />
    </svg>
  );
}
