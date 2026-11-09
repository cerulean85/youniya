// Monthly constellations (기획서 16장). The shape of GET /v1/constellations/{YYYY-MM} as the API Dev Session
// planned it; until that ships, `fromStars` builds the same shape from the month's stars and the shapes below.
import type { Mood, StarSummary } from "./types";

export type CStar = { id: string; title: string; mood: Mood; moods?: Mood[]; has_starlight?: boolean; starlight: number | null; created_at: string };
export type Constellation = {
  month: string; key: string; name: string;
  slots: { index: number; x: number; y: number; star: CStar | null }[];
  lines: number[][];
  extra: CStar[]; filled: number; total: number; complete: boolean;
};

type Shape = { key: string; name: string; slots: number[][]; lines: number[][] };

// The twelve shapes from Figma Mobile 501:13915 (08 월별 별자리 템플릿, 342×300 canvas), slots in fill order,
// as the FIGMA DESIGN Session sent them to the API Dev Session too (2026-11-09).
export const SHAPES: Record<string, Shape> = {"01":{"key":"orion","name":"오리온","slots":[[0.439,0.117],[0.249,0.233],[0.658,0.25],[0.38,0.5],[0.453,0.483],[0.526,0.467],[0.292,0.8],[0.702,0.773]],"lines":[[0,1],[0,2],[1,3],[2,5],[3,4],[4,5],[3,6],[5,7]]},"02":{"key":"gemini","name":"쌍둥이","slots":[[0.278,0.167],[0.512,0.15],[0.292,0.417],[0.249,0.667],[0.19,0.85],[0.512,0.433],[0.556,0.683],[0.629,0.85]],"lines":[[0,1],[0,2],[2,3],[3,4],[1,5],[5,6],[6,7],[2,5]]},"03":{"key":"ursa_major","name":"큰곰","slots":[[0.132,0.4],[0.292,0.333],[0.439,0.4],[0.585,0.467],[0.76,0.433],[0.789,0.633],[0.614,0.667]],"lines":[[0,1],[1,2],[2,3],[3,4],[4,5],[5,6],[6,3]]},"04":{"key":"leo","name":"사자","slots":[[0.322,0.7],[0.424,0.5],[0.38,0.35],[0.482,0.267],[0.585,0.317],[0.687,0.45],[0.848,0.6],[0.687,0.683]],"lines":[[0,1],[1,2],[2,3],[3,4],[1,5],[5,6],[6,7],[7,0],[7,5]]},"05":{"key":"bootes","name":"목동","slots":[[0.439,0.833],[0.322,0.633],[0.351,0.4],[0.482,0.233],[0.599,0.417],[0.57,0.633]],"lines":[[0,1],[1,2],[2,3],[3,4],[4,5],[5,0]]},"06":{"key":"scorpius","name":"전갈","slots":[[0.746,0.15],[0.766,0.283],[0.731,0.407],[0.599,0.45],[0.526,0.583],[0.503,0.717],[0.556,0.833],[0.649,0.873],[0.731,0.817]],"lines":[[0,1],[1,2],[1,3],[3,4],[4,5],[5,6],[6,7],[7,8]]},"07":{"key":"cygnus","name":"백조","slots":[[0.5,0.193],[0.5,0.38],[0.5,0.553],[0.5,0.807],[0.301,0.327],[0.181,0.247],[0.699,0.447],[0.819,0.513]],"lines":[[0,1],[1,2],[2,3],[1,4],[4,5],[1,6],[6,7]]},"08":{"key":"lyra","name":"거문고","slots":[[0.415,0.247],[0.535,0.38],[0.444,0.5],[0.57,0.733],[0.699,0.58]],"lines":[[0,1],[1,2],[2,3],[3,4],[4,1]]},"09":{"key":"aquila","name":"독수리","slots":[[0.5,0.467],[0.444,0.407],[0.556,0.527],[0.275,0.353],[0.725,0.58],[0.5,0.767],[0.585,0.22]],"lines":[[3,1],[1,0],[0,2],[2,4],[0,5],[0,6]]},"10":{"key":"cassiopeia","name":"카시오페이아","slots":[[0.146,0.367],[0.325,0.647],[0.5,0.433],[0.678,0.687],[0.854,0.313]],"lines":[[0,1],[1,2],[2,3],[3,4]]},"11":{"key":"pegasus","name":"페가수스","slots":[[0.395,0.4],[0.678,0.4],[0.678,0.667],[0.395,0.667],[0.784,0.3],[0.854,0.22],[0.251,0.313],[0.146,0.367],[0.287,0.767]],"lines":[[0,1],[1,2],[2,3],[3,0],[1,4],[4,5],[0,6],[6,7],[3,8]]},"12":{"key":"taurus","name":"황소","slots":[[0.497,0.583],[0.424,0.533],[0.351,0.467],[0.161,0.217],[0.541,0.517],[0.585,0.433],[0.716,0.2],[0.819,0.717]],"lines":[[0,1],[1,2],[2,3],[0,4],[4,5],[5,6],[0,7]]}} as Record<string, Shape>;
/** The canvas the coordinates are relative to. */
export const CANVAS = { width: 342, height: 300 };
export const MONTH_NAMES: Record<string, string> = Object.fromEntries(Object.entries(SHAPES).map(([m, s]) => [m, s.name]));
/** 기획서 16장 · 2026-11-09: a deep star has starlight and a depth score of 280 or more (70% of 400). */
export const DEEP_DEPTH = 280;

/** Stand-in for the API: the month's floated stars fill the slots in date order, the rest go to `extra`. */
export function fromStars(month: string, stars: StarSummary[]): Constellation | null {
  const shape = SHAPES[month.slice(5)];
  if (!shape) return null;
  const ordered = [...stars].sort((a, b) => a.created_at.localeCompare(b.created_at)).map((s): CStar => ({
    id: s.id, title: s.title, mood: s.mood, moods: s.moods, has_starlight: s.has_starlight ?? s.state === "floated",
    starlight: s.starlight, created_at: s.created_at,
  }));
  const slots = shape.slots.map(([x, y], index) => ({ index, x, y, star: ordered[index] ?? null }));
  const filled = Math.min(ordered.length, slots.length);
  return { month, key: shape.key, name: shape.name, slots, lines: shape.lines, extra: ordered.slice(slots.length), filled, total: slots.length, complete: filled === slots.length };
}
