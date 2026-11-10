"use server";

import { refresh } from "next/cache";
import { ApiError, keeperAction, refundOrder } from "@/lib/api";
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
  return { ok: `${KEEPER_ACTION_LABEL[action]}: 처리했어요. ${action === "revoke_coins" ? "" : "별지기에게 앱 알림이 가고 "}운영 기록에 남았어요.` };
}

/** 운영자 환불 (owner): Toss cancels the payment and the coins go back; `force` is for exceptions like an outage. */
export async function refund(orderId: string, force: boolean, _prev: ReasonState, form: FormData): Promise<ReasonState> { void _prev;
  const { operator } = await requireOperator();
  if (operator.role !== "owner") return { error: "환불은 운영자(owner)만 할 수 있어요." };
  const reason = String(form.get("reason") ?? "").trim();
  if (!reason) return { error: "사유를 적어 주세요." };
  try {
    const r = await refundOrder(orderId, reason, force);
    refresh();
    return { ok: `환불했어요. 코인 ${r.coins_taken}개를 회수했고, 별지기에게 앱 알림이 가요.` };
  } catch (e) {
    if (e instanceof ApiError) return { error: e.code === "cancel_unconfirmed" ? "토스에서 결과를 받지 못했어요. 잠시 뒤 다시 시도하고, 토스 가맹점 관리자에서 취소됐는지 확인해 주세요." : e.message };
    throw e;
  }
}
