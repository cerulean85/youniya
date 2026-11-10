"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";
import { flash } from "@/lib/flash";

export type NameCheck = { available: boolean; reason: string | null; message: string | null };
export type NameState = { error?: string } | null;

/** 15.1: 2–12 letters (한글·영문·숫자), not taken, not hurtful, not 운영자 or YOUNIYA. */
export async function checkNickname(name: string): Promise<NameCheck> {
  return api<NameCheck>(`/v1/me/nickname/check?name=${encodeURIComponent(name)}`);
}

/** Only paths inside the app, so `next` can't send anyone elsewhere. */
const safeNext = (v: FormDataEntryValue | null) => {
  const s = String(v ?? "");
  return s.startsWith("/") && !s.startsWith("//") ? s : "/";
};

export async function saveNickname(_prev: NameState, form: FormData): Promise<NameState> { void _prev;
  const name = String(form.get("name") ?? "").trim();
  try {
    const had = Boolean((await api<{ nickname?: string | null }>("/v1/me")).nickname);
    await api("/v1/me/nickname", { method: "PUT", body: JSON.stringify({ name }) });
    await flash(had ? "별지기 이름을 바꿨어요" : "별지기 이름을 정했어요");
  } catch (e) {
    // Mobile Nickname: the two codes people meet most, said the way the app says them.
    if (e instanceof ApiError && e.code === "nickname_too_soon") {
      const at = typeof e.data.next_change === "string" ? new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", month: "long", day: "numeric" }).format(new Date(e.data.next_change)) : null;
      return { error: `아직 바꿀 수 없어요. 30일에 한 번 바꿀 수 있어요${at ? ` (${at}부터)` : ""}` };
    }
    if (e instanceof ApiError && e.code === "nickname_taken") return { error: "이미 다른 별지기가 쓰고 있는 이름이에요" };
    if (e instanceof ApiError) return { error: e.message };
    throw e;
  }
  refresh();
  redirect(safeNext(form.get("next")));
}
