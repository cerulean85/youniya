"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";
import type { CreateResult, Mood } from "@/lib/types";

export type DraftInput = { mood: Mood; title: string; body: string };
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
  const input = { mood: String(form.get("mood")) as Mood, title: String(form.get("title") ?? ""), body: String(form.get("body") ?? ""), mode };
  let result: CreateResult;
  try {
    result = await api<CreateResult>("/v1/stars", { method: "POST", body: JSON.stringify(input) });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message, code: e.code, cost: e.data.cost as number, coins: e.data.coins as number };
    throw e;
  }
  await api("/v1/drafts/current", { method: "DELETE" }).catch(() => null);
  const { star, crisis } = result;
  refresh(); // coins and counts in the sidebar
  redirect(crisis ? `/stars/${star.id}?care=1` : mode === "float" ? `/stars/${star.id}?new=1` : `/stars/${star.id}`);
}
