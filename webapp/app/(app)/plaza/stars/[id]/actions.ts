"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";
import type { LineChip } from "@/lib/types";

// 18.3: personal_info and self_harm hide a star at the first report.
const REASON_KEYS = ["hurtful", "personal_info", "self_harm", "harassment", "hate", "impersonation", "advertising", "nickname", "spam", "other"] as const;
const reasonOf = (form: FormData) => {
  const picked = String(form.get("reason") ?? "");
  return (REASON_KEYS as readonly string[]).includes(picked) ? picked : "other";
};

/** A paused plaza (403 plaza_restricted) sends people to the explanation on the plaza. */
async function plaza(call: () => Promise<unknown>) {
  try {
    await call();
  } catch (e) {
    if (e instanceof ApiError && e.code === "plaza_restricted") redirect("/plaza?restricted=1");
    throw e;
  }
}

/** 공명 남기기 / 거두기 (a resonated star also goes beside, 2026-11-08). */
export async function toggleResonance(shareId: string, on: boolean) {
  await plaza(() => api(`/v1/plaza/star/${shareId}/resonance`, { method: on ? "PUT" : "DELETE" }));
  refresh();
}

/** 곁에 두기 / 거두기 */
export async function toggleBeside(shareId: string, on: boolean) {
  await plaza(() => api(`/v1/plaza/star/${shareId}/beside`, { method: on ? "PUT" : "DELETE" }));
  refresh();
}

/** 100 신고하기: it leaves my plaza at once; "이 별지기도 차단하기" blocks its owner too. */
export async function reportShare(shareId: string, form: FormData) {
  await api(`/v1/plaza/star/${shareId}/report`, {
    method: "POST",
    body: JSON.stringify({ reason: reasonOf(form), block: form.get("block") === "on" }),
  });
  refresh();
  redirect("/plaza?reported=1");
}

/** 75-2 차단: neither sees the other's stars or lines anywhere. */
export async function blockOwner(shareId: string) {
  await api("/v1/blocks", { method: "POST", body: JSON.stringify({ star_id: shareId }) });
  refresh();
  redirect("/plaza?blocked=1");
}

export type LineState = { error?: string; code?: string; ok?: boolean } | null;

const LINE_ERRORS: Record<string, string> = {
  empty_line: "한 줄을 적거나 공감 칩을 골라 주세요.",
  too_long: "60자까지 남길 수 있어요.",
  hurtful: "상처 주는 말은 별빛이 되지 못해요. 다른 말로 마음을 전해 주세요.",
  contact: "연락처는 남길 수 없어요.",
  judging: "판단하는 말보다 마음을 전하는 말로 다시 써 주세요.",
  advice: "조언보다는 곁에 있다는 마음을 전해 주세요.",
  already_left: "이 별에는 이미 별빛 한 줄을 건넸어요.",
  lines_closed: "이 별은 지금 별빛 한 줄을 받지 않아요.",
  plaza_restricted: "광장 이용이 잠시 멈춰 있어 별빛 한 줄을 건넬 수 없어요.",
};

/** W-55 별빛 한 줄: one per star per person, 60 characters or a quick chip; only the owner reads it. */
export async function leaveLine(shareId: string, _prev: LineState, form: FormData): Promise<LineState> { void _prev;
  const chip = String(form.get("chip") ?? "") as LineChip | "";
  const text = String(form.get("text") ?? "").trim();
  try {
    await api(`/v1/plaza/stars/${shareId}/lines`, { method: "POST", body: JSON.stringify(chip ? { chip } : { text }) });
  } catch (e) {
    if (e instanceof ApiError) return { error: LINE_ERRORS[e.code] ?? e.message, code: e.code };
    throw e;
  }
  refresh();
  return { ok: true };
}
