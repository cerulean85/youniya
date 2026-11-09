import "server-only";
import { api } from "./api";
import { DEEP_DEPTH, fromStars, type Constellation } from "./constellation";
import type { Star, StarSummary } from "./types";

/** The month's constellation. Uses GET /v1/constellations/{month} once it exists; until then builds it here. */
export async function getConstellation(month: string): Promise<{ c: Constellation | null; stars: StarSummary[] }> {
  const { items } = await api<{ items: StarSummary[] }>(`/v1/stars?month=${month}&limit=200`);
  return { c: fromStars(month, items), stars: items };
}

const lit = (s: StarSummary) => s.has_starlight ?? s.state === "floated";

/** 깊은 별: starlight and a depth score of 280 or more. The list has no scores, so this reads the lit stars. */
export async function countDeep(stars: StarSummary[]): Promise<number> {
  const details = await Promise.all(stars.filter(lit).map((s) => api<Star>(`/v1/stars/${s.id}`)));
  return details.filter((d) => (d.analysis?.scores?.depth ?? Math.round((d.analysis?.depth ?? 0) * 400)) >= DEEP_DEPTH).length;
}
