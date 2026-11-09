"use server";

import { refresh } from "next/cache";
import { ApiError, replyInquiry } from "@/lib/api";
import { requireOperator } from "@/lib/session";

export type ReplyState = { error?: string; ok?: boolean } | null;

/** A-07 답장 보내기: goes to the email the person left with the inquiry. */
export async function sendReply(id: string, _prev: ReplyState, form: FormData): Promise<ReplyState> { void _prev;
  await requireOperator();
  const body = String(form.get("body") ?? "").trim();
  if (!body) return { error: "답장을 적어 주세요." };
  try {
    await replyInquiry(id, body);
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message };
    throw e;
  }
  refresh();
  return { ok: true };
}
