"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";
import type { CreateResult, Mood, Star, StarSummary } from "@/lib/types";

export type ActionState = { error?: string; code?: string } | null;

/** W-56 별빛 받기 for a star without starlight (or a retry after a failed reading): free once a day, then 5 coins. */
export async function floatStar(id: string, _prev: ActionState): Promise<ActionState> { void _prev;
  let r: CreateResult;
  try {
    // `/starlight` is the 2026-11 name; servers without it still have `/float`.
    r = await api<CreateResult>(`/v1/stars/${id}/starlight`, { method: "POST" }).catch((e) => {
      if (e instanceof ApiError && (e.status === 404 || e.status === 405)) return api<CreateResult>(`/v1/stars/${id}/float`, { method: "POST" });
      throw e;
    });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message, code: e.code };
    throw e;
  }
  refresh();
  redirect(r.crisis ? `/stars/${id}?care=1` : `/stars/${id}?new=1`);
}

/** 15 영구 삭제: the writing, its analysis and its plaza share go. */
export async function deleteStar(id: string) {
  await api(`/v1/stars/${id}`, { method: "DELETE" });
  refresh();
  redirect("/records");
}

type Scan = { masked: string; counts: { contacts: number; names: number; places: number }; total: number };

/** 20 공유 전 확인: how each sentence will look once names, places and contacts are masked. */
export async function scanSentences(sentences: string[]) {
  return Promise.all(sentences.map((text) => api<Scan>("/v1/plaza/privacy-scan", { method: "POST", body: JSON.stringify({ text }) })));
}

/** 19 익명으로 나누기: only the chosen sentence goes out, masked by the server. */
export async function shareStar(id: string, form: FormData) {
  const quote = String(form.get("quote") ?? "").trim();
  if (!quote) return;
  await api(`/v1/stars/${id}/share`, { method: "PUT", body: JSON.stringify({ quote }) });
  refresh();
}

export async function unshareStar(id: string) {
  await api(`/v1/stars/${id}/share`, { method: "DELETE" });
  refresh();
}

/** W-54 마음 망원경 켜기 for this one star: free while free ones are left, then coins. */
export async function openTelescope(id: string, _prev: ActionState): Promise<ActionState> { void _prev;
  try {
    await api(`/v1/telescope/reports`, { method: "POST", body: JSON.stringify({ star_ids: [id] }) });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message, code: e.code };
    throw e;
  }
  refresh();
  return null;
}

const LINKS_SOON = "별 잇기는 곧 열려요. 서버 준비가 끝나면 바로 쓸 수 있어요.";

/** W-51 이미 쓴 별과 잇기. */
export async function linkStars(id: string, starIds: string[]): Promise<ActionState> {
  try {
    await api(`/v1/stars/${id}/links`, { method: "POST", body: JSON.stringify({ star_ids: starIds }) });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.status === 404 || e.status === 405 ? LINKS_SOON : e.message, code: e.code };
    throw e;
  }
  refresh();
  return null;
}

/** 이어진 별 chips: a link can be cut at any time (W-47). */
export async function unlinkStar(id: string, other: string) {
  await api(`/v1/stars/${id}/links/${other}`, { method: "DELETE" });
  refresh();
}

export type PickItem = { id: string; title: string; mood: Mood; created_at: string; starlight: number | null; lit: boolean };

/** The W-51 list (search and filters) or the W-52 calendar month, without this star. */
export async function pickerStars(id: string, f: { q?: string; filter?: string; month?: string }): Promise<PickItem[]> {
  const p = new URLSearchParams({ limit: f.month ? "200" : "60" });
  if (f.q) p.set("q", f.q);
  if (f.month) p.set("month", f.month);
  if (f.filter === "lit") p.set("state", "floated");
  else if (f.filter === "unlit") p.set("state", "kept");
  else if (f.filter && f.filter !== "all") p.set("mood", f.filter);
  const { items } = await api<{ items: StarSummary[] }>(`/v1/stars?${p}`);
  return items.filter((s) => s.id !== id).map((s) => ({
    id: s.id, title: s.title || "제목 없는 별", mood: s.mood, created_at: s.created_at, starlight: s.starlight,
    lit: s.has_starlight ?? s.state === "floated",
  }));
}

/** W-53: a star's writing before choosing it. */
export async function previewStar(id: string) {
  const s = await api<Star>(`/v1/stars/${id}`);
  return { id: s.id, title: s.title || "제목 없는 별", body: s.body, created_at: s.created_at,
    lit: s.has_starlight ?? s.state === "floated", links: s.linked_stars ?? [] };
}

/** W-33 글 수정: a star without starlight can still change its moods, title and writing. */
export async function editStar(id: string, _prev: ActionState, form: FormData): Promise<ActionState> { void _prev;
  const moods = String(form.get("moods") ?? "").split(",").filter(Boolean) as Mood[];
  const input = { mood: moods[0], moods, title: String(form.get("title") ?? ""), body: String(form.get("body") ?? "") };
  try {
    await api(`/v1/stars/${id}`, { method: "PATCH", body: JSON.stringify(input) });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message, code: e.code };
    throw e;
  }
  refresh();
  redirect(`/stars/${id}`);
}
