import "server-only";
import { api, ApiError } from "./api";
import { DEEP_DEPTH, fromStars, type Constellation } from "./constellation";
import type { Star, StarSummary } from "./types";

export type MonthItem = { month: string; key: string; name: string; filled: number; total: number; complete: boolean };
export type MonthView = { c: Constellation | null; count: number; lit: number; unlit: number; deep: number };
export type StoryEntry = { star_id: string; date: string; title: string; sentence: string; has_starlight?: boolean };

/** A server without the constellation API answers with a bare 404 or 405; a closed month is a 404 `not_found`. */
const missing = (e: unknown) => e instanceof ApiError && (e.status === 405 || (e.status === 404 && e.code !== "not_found"));
const closed = (e: unknown) => e instanceof ApiError && e.status === 404 && e.code === "not_found";

/** Months from sign-up to now, newest first (GET /v1/constellations); null on a server without it. */
export async function listMonths(): Promise<MonthItem[] | null> {
  try {
    return (await api<{ items: MonthItem[] }>("/v1/constellations")).items;
  } catch (e) {
    if (missing(e)) return null;
    throw e;
  }
}

/** The month's constellation, or null for a month that isn't open (before sign-up, or not yet come). */
export async function getConstellation(month: string): Promise<MonthView | null> {
  try {
    const c = await api<Constellation & { lit: number; unlit: number; deep: number }>(`/v1/constellations/${month}`);
    return { c, count: c.filled + c.extra.length, lit: c.lit, unlit: c.unlit, deep: c.deep };
  } catch (e) {
    if (closed(e)) return null;
    if (!missing(e)) throw e;
  }
  // Older servers: build it here from the month's stars.
  const { items } = await api<{ items: StarSummary[] }>(`/v1/stars?month=${month}&limit=200`);
  const lit = items.filter((s) => s.has_starlight ?? s.state === "floated");
  const details = await Promise.all(lit.map((s) => api<Star>(`/v1/stars/${s.id}`)));
  const deep = details.filter((d) => (d.analysis?.scores?.depth ?? Math.round((d.analysis?.depth ?? 0) * 400)) >= DEEP_DEPTH).length;
  return { c: fromStars(month, items), count: items.length, lit: lit.length, unlit: items.length - lit.length, deep };
}

/** 별자리 이야기: a sentence per star in time order (the prism's for lit stars, the first one otherwise). */
export async function getStory(month: string): Promise<StoryEntry[] | null> {
  try {
    return (await api<{ entries: StoryEntry[] }>(`/v1/constellations/${month}/story`)).entries;
  } catch (e) {
    if (closed(e)) return null;
    if (!missing(e)) throw e;
  }
  const { items } = await api<{ items: StarSummary[] }>(`/v1/stars?month=${month}&limit=60`);
  const stars = await Promise.all([...items].sort((a, b) => a.created_at.localeCompare(b.created_at)).map((s) => api<Star>(`/v1/stars/${s.id}`)));
  return stars.map((s) => ({
    star_id: s.id, date: s.created_at, title: s.title,
    sentence: s.analysis?.impact_quote || s.body.split(/(?<=[.!?。…])\s+|\n+/)[0].trim(),
  }));
}
