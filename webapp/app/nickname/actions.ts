"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";

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
    await api("/v1/me/nickname", { method: "PUT", body: JSON.stringify({ name }) });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message };
    throw e;
  }
  refresh();
  redirect(safeNext(form.get("next")));
}
