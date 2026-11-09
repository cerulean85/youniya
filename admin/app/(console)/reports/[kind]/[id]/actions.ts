"use server";

import { refresh } from "next/cache";
import { act, ApiError } from "@/lib/api";
import { requireOperator } from "@/lib/session";
import type { ActionKind, ReportKind } from "@/lib/types";

export type ActState = { error?: string; ok?: string } | null;

const ACTIONS: ActionKind[] = ["restore", "take_down", "request_rename", "restrict_7d", "restrict_30d", "note"];

/** Every action needs a reason (18.1); the keeper hears of it through an app notice and it's logged. */
export async function takeAction(kind: ReportKind, id: string, _prev: ActState, form: FormData): Promise<ActState> { void _prev;
  await requireOperator();
  const action = String(form.get("action")) as ActionKind;
  const reason = String(form.get("reason") ?? "").trim();
  if (!ACTIONS.includes(action)) return { error: "알 수 없는 조치예요." };
  if (!reason) return { error: "사유를 적어 주세요." };
  try {
    await act(kind, id, action, reason, String(form.get("note") ?? "").trim() || undefined);
  } catch (e) {
    if (e instanceof ApiError) return { error: e.code === "forbidden_role" ? "이 조치를 할 권한이 없어요." : e.message };
    throw e;
  }
  refresh();
  return { ok: "조치했어요." };
}
