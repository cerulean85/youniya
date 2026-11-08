import Link from "next/link";
import { moodOf } from "@/lib/format";
import type { StarSummary } from "@/lib/types";

// The recent floated stars as a constellation: spread left to right in the order they were floated,
// height from a hash of the id, size from starlight, colour from mood.
function hash(id: string) {
  let h = 0;
  for (const c of id) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return h;
}

export function Constellation({ stars }: { stars: StarSummary[] }) {
  const pts = [...stars].reverse().map((s, i, all) => {
    const x = all.length === 1 ? 300 : 60 + (480 * i) / (all.length - 1);
    const y = 70 + (hash(s.id) % 220);
    const r = 5 + Math.round(((s.starlight ?? 300) / 999) * 7);
    return { s, x, y, r, color: moodOf(s.mood).color };
  });
  return (
    <svg viewBox="0 0 600 360" width="100%" height="100%" role="img" aria-label={`최근 띄운 별 ${stars.length}개`}>
      <polyline points={pts.map((p) => `${p.x},${p.y}`).join(" ")} fill="none" stroke="#E2E8F0" strokeOpacity={0.35} strokeDasharray="3 5" />
      {pts.map((p) => (
        <Link key={p.s.id} href={`/stars/${p.s.id}`} prefetch={false}>
          <circle cx={p.x} cy={p.y} r={p.r} fill={p.color} style={{ filter: `drop-shadow(0 0 8px ${p.color})` }}>
            <title>{`${p.s.title || "제목 없는 별"} · ${p.s.starlight ?? ""} 별빛`}</title>
          </circle>
        </Link>
      ))}
    </svg>
  );
}
