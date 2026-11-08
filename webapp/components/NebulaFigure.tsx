import { moodOf } from "@/lib/format";
import { places, type Figure } from "@/lib/nebula";

// Draws a nebula from its data, like the iOS NebulaFigureView: mood-coloured stars on the silhouette's
// places, guests with gold rings, faint empty places, and thin gold lines.
/** `dotScale` enlarges the dots for small thumbnails, where point-sized dots would vanish. */
export function NebulaFigure({ figure, width = 400, height = 400, compact = false, dotScale = 1, label }: { figure: Figure; width?: number; height?: number; compact?: boolean; dotScale?: number; label?: string }) {
  const pts = places(figure, width, height);
  const filled = Math.min(pts.length, figure.dots.length);
  // iOS sizes are points on a ~340pt-wide canvas; scale them with this canvas.
  const k = (compact ? 0.6 : 1) * (width / 340) * dotScale;
  const line = figure.silhouette
    ? pts.slice(0, filled).map((p, i) => `${i ? "L" : "M"}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(" ")
    : figure.edges.filter((e) => e.length === 2 && e.every((i) => i < filled)).map(([a, b]) => `M${pts[a][0]} ${pts[a][1]} L${pts[b][0]} ${pts[b][1]}`).join(" ");
  return (
    <svg viewBox={`0 0 ${width} ${height}`} width="100%" height="100%" role="img" aria-label={label ?? `별 ${figure.dots.length}개로 그린 성운`}>
      {line && <path d={line} fill="none" stroke="#fbbf24" strokeOpacity={0.55} strokeWidth={(compact ? 0.8 : 1) * (width / 340)} />}
      {pts.map((p, i) => {
        if (i < filled) {
          const dot = figure.dots[i];
          const color = dot.guest ? "#fbbf24" : dot.mood ? moodOf(dot.mood).color : "#fbbf24";
          const size = [8, 10, 9][i % 3] * k;
          return dot.guest ? (
            <g key={i}><circle cx={p[0]} cy={p[1]} r={8 * k} fill="none" stroke="#fbbf24" strokeWidth={1.2 * k} /><circle cx={p[0]} cy={p[1]} r={4 * k} fill={color} /></g>
          ) : (
            <circle key={i} cx={p[0]} cy={p[1]} r={size / 2} fill={color} style={{ filter: `drop-shadow(0 0 ${5 * k}px ${color})` }} />
          );
        }
        return figure.silhouette ? <circle key={i} cx={p[0]} cy={p[1]} r={4 * k} fill="none" stroke="#8090a6" strokeOpacity={0.5} strokeWidth={k} strokeDasharray={`${2 * k} ${2 * k}`} /> : null;
      })}
    </svg>
  );
}
