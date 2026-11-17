"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { publicApi } from "@/lib/api";
import { storeTokens, type Tokens } from "@/lib/session";

export type InviteState = { error: string } | null;

// 02-1 초대 계정으로 로그인 (as on iOS): accounts the team hands out, for App Review and the Toss review.
export async function inviteSignIn(_: InviteState, form: FormData): Promise<InviteState> {
  const login = String(form.get("login") ?? "").trim();
  const password = String(form.get("password") ?? "");
  if (!login || !password) return { error: "아이디와 비밀번호를 모두 적어 주세요." };
  let r: Awaited<ReturnType<typeof publicApi<Tokens>>>;
  try {
    r = await publicApi<Tokens>("/v1/auth/invite", { login, password });
  } catch {
    return { error: "서버에 닿지 못했어요. 잠시 뒤에 다시 시도해 주세요." };
  }
  if (r.status === 401) return { error: "아이디나 비밀번호가 맞지 않아요." };
  if (r.status === 429) return { error: "시도가 너무 많았어요. 1분 뒤에 다시 시도해 주세요." };
  if (!r.ok) return { error: "로그인하지 못했어요. 잠시 뒤에 다시 시도해 주세요." };
  storeTokens(await cookies(), r.data);
  redirect(r.data.needs_consent ? "/welcome" : "/");
}
