"use server";

import { refresh } from "next/cache";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";
import { flash } from "@/lib/flash";
import { clearTokens } from "@/lib/session";

/** 14.3 새 기능·혜택 알림: its own consent, recorded with when it was given or taken back. */
export async function setMarketing(on: boolean) {
  await api("/v1/me/marketing", { method: "PUT", body: JSON.stringify({ opt_in: on }) });
  refresh();
}

/** 애니메이션 줄이기 (iOS 87): kept with the account, so the app and the web follow the same choice. */
export async function setReduceMotion(on: boolean) {
  await api("/v1/me/settings", { method: "PATCH", body: JSON.stringify({ reduce_animations: on }) });
  refresh();
}

/** W-77: one shared star leaves the plaza; lines and resonance already given stay. */
export async function unshareOne(starId: string) {
  await api(`/v1/stars/${starId}/share`, { method: "DELETE" });
  await flash("광장에서 거뒀어요", "언제든 다시 나눌 수 있어요");
  refresh();
}

export async function unblock(id: string) {
  await api(`/v1/blocks/${id}`, { method: "DELETE" });
  await flash("차단을 풀었어요", "이 사람의 글이 다시 보여요");
  refresh();
}

/** 92 모든 공유 거두기: every shared star leaves the plaza; lines and resonance already given stay. */
export async function unshareAll() {
  await api("/v1/me/shares", { method: "DELETE" });
  await flash("나눈 별을 모두 거뒀어요", "받은 공명과 별빛 한 줄은 그대로 남아요");
  refresh();
}

/** 91 계정 영구 삭제: everything goes except store purchase records (kept 5 years by law). */
export async function deleteAccount(form: FormData) {
  if (form.get("confirm") !== "삭제") return;
  await api("/v1/me", { method: "DELETE" });
  clearTokens(await cookies());
  redirect("/deleted"); // W-83
}

/** 우주의 색: violet and ocean for everyone; the rest answer 403 member_only for non-members. */
export async function setSky(sky: string): Promise<{ error?: string } | null> {
  try {
    await api("/v1/me/settings", { method: "PATCH", body: JSON.stringify({ sky }) });
  } catch (e) {
    if (e instanceof ApiError && e.code === "member_only") return { error: "이 색은 별지기 멤버십에서 쓸 수 있어요." };
    if (e instanceof ApiError) return { error: e.message };
    throw e;
  }
  refresh();
  return null;
}
