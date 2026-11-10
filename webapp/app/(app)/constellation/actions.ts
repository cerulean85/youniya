"use server";

import { api } from "@/lib/api";
import type { Star } from "@/lib/types";

/** W-16-1: the chosen star's links, to draw the silver lines and say what's beyond this month. */
export async function starLinks(id: string) {
  const s = await api<Star>(`/v1/stars/${id}`);
  return (s.linked_stars ?? []).map((l) => ({ id: l.id, created_at: l.created_at }));
}
