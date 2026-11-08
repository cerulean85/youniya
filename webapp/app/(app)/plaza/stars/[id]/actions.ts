"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";

const REASONS = ["hurtful", "personal_info", "spam", "other"] as const;
export type Kind = "star" | "nebula";
const reasonOf = (form: FormData) => {
  const picked = String(form.get("reason") ?? "");
  return (REASONS as readonly string[]).includes(picked) ? picked : "other";
};

/** 공명 남기기 / 거두기 */
export async function toggleResonance(kind: Kind, shareId: string, on: boolean) {
  await api(`/v1/plaza/${kind}/${shareId}/resonance`, { method: on ? "PUT" : "DELETE" });
  refresh();
}

/** 곁에 두기 / 거두기 (컬렉션) */
export async function toggleBeside(kind: Kind, shareId: string, on: boolean) {
  await api(`/v1/plaza/${kind}/${shareId}/beside`, { method: on ? "PUT" : "DELETE" });
  refresh();
}

/** 100 신고하기: it leaves my plaza at once; "이 별지기도 차단하기" blocks its owner too. */
export async function reportShare(kind: Kind, shareId: string, form: FormData) {
  await api(`/v1/plaza/${kind}/${shareId}/report`, {
    method: "POST",
    body: JSON.stringify({ reason: reasonOf(form), block: form.get("block") === "on" }),
  });
  refresh();
  redirect("/plaza?reported=1");
}

/** 75-2 차단: neither sees the other's shares anywhere. */
export async function blockOwner(kind: Kind, shareId: string) {
  await api("/v1/blocks", { method: "POST", body: JSON.stringify(kind === "star" ? { star_id: shareId } : { nebula_id: shareId }) });
  refresh();
  redirect("/plaza?blocked=1");
}

export type LineState = { error?: string; code?: string; ok?: boolean } | null;

/** 74 별빛 한 줄: one line per nebula per person, 60 characters, gone after a day. */
export async function leaveLine(shareId: string, _prev: LineState, form: FormData): Promise<LineState> {
  void _prev;
  const text = String(form.get("text") ?? "").trim();
  if (!text) return { error: "한 줄을 적어 주세요." };
  try {
    await api(`/v1/plaza/nebulae/${shareId}/lines`, { method: "POST", body: JSON.stringify({ text }) });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.code === "hurtful" ? "이 한 줄은 남길 수 없어요. 다른 말로 마음을 전해 주세요." : e.message, code: e.code };
    throw e;
  }
  refresh();
  return { ok: true };
}

/** 100 별빛 한 줄 신고 → 101 신고를 받았어요. */
export async function reportLine(lineId: string, form: FormData) {
  await api(`/v1/plaza/lines/${lineId}/report`, { method: "POST", body: JSON.stringify({ reason: reasonOf(form), block: form.get("block") === "on" }) });
  refresh();
}
