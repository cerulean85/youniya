"use server";

import { refresh } from "next/cache";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { api } from "@/lib/api";
import { clearTokens } from "@/lib/session";

/** 14.3 새 기능·혜택 알림: its own consent, recorded with when it was given or taken back. */
export async function setMarketing(on: boolean) {
  await api("/v1/me/marketing", { method: "PUT", body: JSON.stringify({ opt_in: on }) });
  refresh();
}

export async function unblock(id: string) {
  await api(`/v1/blocks/${id}`, { method: "DELETE" });
  refresh();
}

/** 92 모든 공유 거두기: every shared star leaves the plaza; lines and resonance already given stay. */
export async function unshareAll() {
  await api("/v1/me/shares", { method: "DELETE" });
  refresh();
}

/** 91 계정 영구 삭제: everything goes except store purchase records (kept 5 years by law). */
export async function deleteAccount(form: FormData) {
  if (form.get("confirm") !== "삭제") return;
  await api("/v1/me", { method: "DELETE" });
  clearTokens(await cookies());
  redirect("/login?deleted=1");
}
