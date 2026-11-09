"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";
import type { CreateResult, Mood } from "@/lib/types";

export type DraftInput = { mood: Mood; moods: Mood[]; title: string; body: string; source_star_id?: string | null };
export type CreateState = { error?: string; code?: string; cost?: number; coins?: number } | null;

/** 34 임시 저장: the draft lives in the database, one per person. */
export async function saveDraft(d: DraftInput) {
  if (!d.title.trim() && !d.body.trim()) {
    await api("/v1/drafts/current", { method: "DELETE" });
    return;
  }
  await api("/v1/drafts/current", { method: "PUT", body: JSON.stringify(d) });
}

export async function createStar(_: CreateState, form: FormData): Promise<CreateState> {
  const mode = form.get("mode") === "float" ? "float" : "keep";
  // Several moods, the first being the colour (기획서 17.1). Until the API takes `moods`, `mood` carries the first.
  const moods = String(form.get("moods") ?? "").split(",").filter(Boolean) as Mood[];
  const mood = moods[0] ?? "calm";
  // 고쳐 쓰기 (W-46) makes a new star from an old one; 별 잇기 (W-39) joins the new star to one already written.
  const rewriteOf = String(form.get("rewrite_of") ?? "") || null;
  const linkTo = String(form.get("link_to") ?? "") || null;
  const input = { mood, moods, title: String(form.get("title") ?? ""), body: String(form.get("body") ?? ""), mode,
    ...(rewriteOf && { rewrite_of: rewriteOf }), ...(linkTo && { link_to: [linkTo] }) };
  let result: CreateResult;
  try {
    result = await api<CreateResult>("/v1/stars", { method: "POST", body: JSON.stringify(input) });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message, code: e.code, cost: e.data.cost as number, coins: e.data.coins as number };
    throw e;
  }
  const { star, crisis } = result;
  refresh(); // coins and counts in the sidebar
  redirect(crisis ? `/stars/${star.id}?care=1` : mode === "float" ? `/stars/${star.id}?new=1` : `/stars/${star.id}?kept=1`);
}
