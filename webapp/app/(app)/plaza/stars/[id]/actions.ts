"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api } from "@/lib/api";

const REASONS = ["hurtful", "personal_info", "spam", "other"] as const;

/** 공명 남기기 / 거두기 */
export async function toggleResonance(shareId: string, on: boolean) {
  await api(`/v1/plaza/star/${shareId}/resonance`, { method: on ? "PUT" : "DELETE" });
  refresh();
}

/** 곁에 두기 / 거두기 (컬렉션) */
export async function toggleBeside(shareId: string, on: boolean) {
  await api(`/v1/plaza/star/${shareId}/beside`, { method: on ? "PUT" : "DELETE" });
  refresh();
}

/** 100 신고하기: the star leaves my plaza at once; "이 별지기도 차단하기" blocks its owner too. */
export async function reportStar(shareId: string, form: FormData) {
  const picked = String(form.get("reason") ?? "");
  const reason = (REASONS as readonly string[]).includes(picked) ? picked : "other";
  await api(`/v1/plaza/star/${shareId}/report`, {
    method: "POST",
    body: JSON.stringify({ reason, block: form.get("block") === "on" }),
  });
  refresh();
  redirect("/plaza?reported=1");
}

/** 75-2 차단: neither sees the other's shares anywhere. */
export async function blockOwner(shareId: string) {
  await api("/v1/blocks", { method: "POST", body: JSON.stringify({ star_id: shareId }) });
  refresh();
  redirect("/plaza?blocked=1");
}
