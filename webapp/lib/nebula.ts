// A port of the iOS NebulaFigure (ios/Youniya/DesignSystem/NebulaFigure.swift and NebulaSilhouette in
// Screens/NebulaDrawing.swift), so a nebula is drawn the same on the web as on the iPhone.
import type { Mood } from "./types";

type P = [number, number];
type Outline = { points: P[]; closed: boolean; box: [number, number] };

export const SILHOUETTES: Record<string, { name: string; outline: Outline; member?: boolean }> = {
  whale: { name: "고래", outline: { points: [[0, 13], [10, 3], [26, 0], [42, 4], [52, 13], [40, 21], [20, 22]], closed: true, box: [52, 22] } },
  lighthouse: { name: "등대", outline: { points: [[0, 176], [80, 176], [65, 36], [40, 0], [15, 36]], closed: true, box: [80, 176] } },
  tree: { name: "나무", outline: { points: [[14, 32], [14, 20], [0, 18], [14, 0], [28, 18], [14, 20]], closed: false, box: [28, 32] } },
  bird: { name: "새", outline: { points: [[0, 10], [14, 0], [26, 8], [38, 0], [52, 10]], closed: false, box: [52, 10] } },
  flower: { name: "꽃", outline: { points: [[13.3, 0], [26.6, 9.7], [21.5, 25.3], [5.1, 25.3], [0, 9.7]], closed: true, box: [26.6, 25.3] } },
  cherry_blossom: { name: "벚꽃", member: true, outline: { points: [[15.2, 15.2], [15.2, 0], [15.2, 15.2], [30.4, 10.5], [15.2, 15.2], [24.6, 27.5], [15.2, 15.2], [5.8, 27.5], [15.2, 15.2], [0, 10.5]], closed: false, box: [30.4, 27.5] } },
  wave: { name: "파도", member: true, outline: { points: [[0, 18], [10, 6], [20, 14], [30, 0], [40, 12], [52, 4]], closed: false, box: [52, 18] } },
  maple: { name: "단풍", member: true, outline: { points: [[22, 0], [30, 10], [44, 8], [36, 20], [40, 32], [22, 26], [4, 32], [8, 20], [0, 8], [14, 10]], closed: true, box: [44, 32] } },
  snowflake: { name: "눈송이", member: true, outline: { points: [[17, 14.7], [34, 14.7], [17, 14.7], [25.5, 29.4], [17, 14.7], [8.5, 29.4], [17, 14.7], [0, 14.7], [17, 14.7], [8.5, 0], [17, 14.7], [25.5, 0]], closed: false, box: [34, 29.4] } },
};
export const BASIC_SILHOUETTES = ["whale", "lighthouse", "tree", "bird", "flower"] as const;
export const SLOT_COUNT = 18;
export const MIN_STARS = 3;
export const MAX_NAME = 20;
export const MAX_GUESTS = 5;

type Rect = { x: number; y: number; w: number; h: number };

function fitted(o: Outline, r: Rect): P[] {
  const s = Math.min(r.w / o.box[0], r.h / o.box[1]);
  const ox = r.x + r.w / 2 - (o.box[0] * s) / 2, oy = r.y + r.h / 2 - (o.box[1] * s) / 2;
  return o.points.map(([x, y]) => [ox + x * s, oy + y * s]);
}

/** `count` points spread evenly along the outline. */
function slots(o: Outline, r: Rect, count: number): P[] {
  const pts = fitted(o, r);
  if (o.closed) pts.push(pts[0]);
  const segs = pts.slice(1).map((b, i) => Math.hypot(b[0] - pts[i][0], b[1] - pts[i][1]));
  const total = segs.reduce((a, b) => a + b, 0);
  if (total <= 0) return [];
  const step = o.closed ? total / count : total / Math.max(1, count - 1);
  return Array.from({ length: count }, (_, i) => {
    let d = i * step;
    for (let k = 0; k < segs.length; k++) {
      if (d <= segs[k] || k === segs.length - 1) {
        const t = segs[k] > 0 ? Math.min(1, d / segs[k]) : 0;
        const [a, b] = [pts[k], pts[k + 1]];
        return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t] as P;
      }
      d -= segs[k];
    }
    return pts[pts.length - 1];
  });
}

export type Dot = { mood?: Mood | null; guest?: boolean };
export type Figure = { silhouette: string | null; dots: Dot[]; edges: number[][] };

/** Where each place sits: the silhouette's places, or a spiral for 직접 그리기. */
export function places(f: Figure, w: number, h: number): P[] {
  const r = { x: w * 0.13, y: h * 0.14, w: w * 0.74, h: h * 0.72 };
  const sil = f.silhouette ? SILHOUETTES[f.silhouette] : null;
  if (sil) return slots(sil.outline, r, Math.max(SLOT_COUNT, f.dots.length));
  const n = Math.max(f.dots.length, 1);
  return Array.from({ length: n }, (_, i) => {
    const rr = Math.sqrt((i + 0.5) / n), a = i * 2.39996;
    return [r.x + r.w / 2 + (r.w / 2) * rr * Math.cos(a), r.y + r.h / 2 + (r.h / 2) * rr * Math.sin(a)] as P;
  });
}

/** The outline itself, for the silhouette picker. */
export function outlinePath(key: string, w: number, h: number) {
  const o = SILHOUETTES[key].outline;
  const pts = fitted(o, { x: 4, y: 4, w: w - 8, h: h - 8 });
  return `M${pts.map((p) => p.map((v) => v.toFixed(1)).join(" ")).join(" L")}${o.closed ? " Z" : ""}`;
}
