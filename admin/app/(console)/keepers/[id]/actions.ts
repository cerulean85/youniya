"use server";

import { refresh } from "next/cache";
import { ApiError, keeperAction } from "@/lib/api";
import { requireOperator } from "@/lib/session";
import { KEEPER_ACTION_LABEL, MODERATOR_KEEPER_ACTIONS, type KeeperAction } from "@/lib/types";
import type { ReasonState } from "@/components/ReasonActions";

export async function actOnKeeper(id: string, _prev: ReasonState, form: FormData): Promise<ReasonState> { void _prev;
  const { operator } = await requireOperator();
  const action = String(form.get("action")) as KeeperAction;
  if (!(action in KEEPER_ACTION_LABEL)) return { error: "알 수 없는 조치예요." };
  if (operator.role !== "owner" && !MODERATOR_KEEPER_ACTIONS.includes(action)) return { error: "이 조치를 할 권한이 없어요." };
  const reason = String(form.get("reason") ?? "").trim();
  if (!reason) return { error: "사유를 적어 주세요." };
  const amount = form.get("amount") ? Number(form.get("amount")) : undefined;
  const days = form.get("days") ? Number(form.get("days")) : undefined;
  try {
    await keeperAction(id, action, reason, amount, days);
  } catch (e) {
    if (e instanceof ApiError) return { error: e.code === "forbidden_role" ? "이 조치를 할 권한이 없어요." : e.message };
    throw e;
  }
  refresh();
  return { ok: `${KEEPER_ACTION_LABEL[action]}: 처리했어요. 별지기에게 앱 알림이 가고 운영 기록에 남았어요.` };
}
