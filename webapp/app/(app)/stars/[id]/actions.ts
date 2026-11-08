"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";
import type { CreateResult } from "@/lib/types";

export type ActionState = { error?: string; code?: string } | null;

/** Float a kept star (or retry one whose analysis failed): free once a day, then 5 coins. */
export async function floatStar(id: string, _prev: ActionState): Promise<ActionState> { void _prev;
  let r: CreateResult;
  try {
    r = await api<CreateResult>(`/v1/stars/${id}/float`, { method: "POST" });
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
