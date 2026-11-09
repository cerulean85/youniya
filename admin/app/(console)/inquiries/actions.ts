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
    if (e instanceof ApiError) {
      if (e.code === "mail_unavailable") return { error: "메일 발송이 아직 설정되지 않았어요(Resend 키 없음). 답장은 보내지 않았어요." };
      if (e.code === "mail_failed") return { error: "메일을 보내지 못했어요. 잠시 뒤에 다시 시도해 주세요." };
      return { error: e.message };
    }
    throw e;
  }
  refresh();
  return { ok: true };
}
