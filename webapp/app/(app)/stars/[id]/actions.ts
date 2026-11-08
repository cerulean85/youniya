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
