"use server";

import { refresh } from "next/cache";
import { headers } from "next/headers";
import type { ReasonState } from "@/components/ReasonActions";
import * as api from "@/lib/api";
import { requireOperator } from "@/lib/session";

// Server actions for the owner screens. Every one needs a reason, and the API logs it (18.1).
async function run(form: FormData, f: (reason: string) => Promise<unknown>, ok: string): Promise<ReasonState> {
  await requireOperator(["owner"]);
  const reason = String(form.get("reason") ?? "").trim();
  if (!reason) return { error: "사유를 적어 주세요." };
  try {
    await f(reason);
  } catch (e) {
    if (e instanceof api.ApiError) return { error: e.code === "forbidden_role" ? "이 조치를 할 권한이 없어요." : e.message };
    throw e;
  }
  refresh();
  return { ok };
}
const str = (form: FormData, k: string) => String(form.get(k) ?? "").trim();

export async function prismAction(key: string, _p: ReasonState, form: FormData) {
  return str(form, "action") === "deploy"
    ? run(form, (r) => api.deployPrism(key, r), "배포했어요. 이제부터 새로 별빛을 받는 별은 이 방식으로 읽어요.")
    : run(form, (r) => api.testPrism(key, r), "시험을 마쳤어요. 결과를 확인해 주세요.");
}

export async function invitesSetting(on: boolean, _p: ReasonState, form: FormData) {
  return run(form, (r) => api.setInvitesEnabled(on, r), on ? "초대 계정 로그인을 켰어요." : "초대 계정 로그인을 껐어요.");
}

export async function inviteAction(id: string, _p: ReasonState, form: FormData): Promise<ReasonState> {
  const a = str(form, "action");
  if (a === "reset_password") {
    let password: string | undefined;
    const r = await run(form, async (reason) => { password = (await api.resetInvitePassword(id, reason)).password; }, "새 비밀번호예요. 지금 한 번만 보여요.");
    return r?.error || !password ? r : { ...r, secret: password };
  }
  return run(form, (r) => api.setInvite(id, a === "enable", r), a === "enable" ? "켰어요." : "껐어요.");
}

export type CreatedInvite = (ReasonState & { password?: string; loginId?: string }) | null;
/** 새 초대 계정: the password shows once, here, and is never stored in the console. */
export async function newInvite(_p: CreatedInvite, form: FormData): Promise<CreatedInvite> {
  let password: string | undefined;
  const loginId = str(form, "login_id");
  const r = await run(form, async (reason) => { password = (await api.createInvite(loginId, str(form, "memo"), reason)).password; }, "초대 계정을 만들었어요.");
  return { ...r, password, loginId };
}

export async function noticesAction(_p: ReasonState, form: FormData) {
  const a = str(form, "action");
  if (a === "maintenance_on" || a === "maintenance_off") {
    const hours = Number(str(form, "hours") || 2);
    const until = a === "maintenance_on" ? new Date(Date.now() + hours * 3600000).toISOString() : undefined;
    return run(form, (r) => api.setMaintenance(a === "maintenance_on", r, until), a === "maintenance_on" ? `점검 모드를 켰어요. ${hours}시간 뒤 저절로 꺼져요.` : "점검 모드를 껐어요.");
  }
  if (a === "min_version") return run(form, (r) => api.setMinVersion(str(form, "ios"), r), "최소 앱 버전을 바꿨어요.");
  const publish = str(form, "publish_at");
  return run(form, (r) => api.createNotice({ title: str(form, "title"), body: str(form, "body"), publish_at: publish ? new Date(publish).toISOString() : undefined, push: str(form, "push") === "yes" }, r),
    publish ? "공지를 예약했어요." : "공지를 올렸어요.");
}

export async function operatorsAction(id: string | null, _p: ReasonState, form: FormData) {
  const a = str(form, "action");
  if (a === "invite") {
    const role = str(form, "role") === "owner" ? "owner" : "moderator";
    let setup: string | undefined;
    const r = await run(form, async (reason) => { setup = (await api.inviteOperator(str(form, "email"), role, reason)).setup_token; },
      "초대했어요. 아래 설정 링크를 초대한 분께 전해 주세요. 3일 동안 한 번만 쓸 수 있고, 지금만 보여요.");
    if (!setup || r?.error) return r;
    const h = await headers();
    return { ...r, secret: `${h.get("x-forwarded-proto") ?? "http"}://${h.get("host")}/setup?token=${setup}` };
  }
  if (!id) return { error: "운영자를 골라 주세요." };
  if (a === "disable") return run(form, (r) => api.updateOperator(id, { status: "disabled" }, r), "사용을 멈췄어요.");
  if (a === "enable") return run(form, (r) => api.updateOperator(id, { status: "active" }, r), "다시 쓸 수 있게 했어요.");
  const role = a === "make_owner" ? "owner" : "moderator";
  return run(form, (r) => api.updateOperator(id, { role }, r), "권한을 바꿨어요.");
}
