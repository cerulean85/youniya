"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ApiError, login, logout, totp } from "@/lib/api";
import { CHALLENGE, cookieOptions, OPERATOR, session, TOKEN } from "@/lib/session";

export type LoginState = { step: "password" | "code"; error?: string } | null;

const lockedUntil = (e: ApiError) => {
  const until = e.data.until ? new Date(String(e.data.until)) : null;
  return until ? new Intl.DateTimeFormat("ko-KR", { hour: "2-digit", minute: "2-digit", hourCycle: "h23", timeZone: "Asia/Seoul" }).format(until) : null;
};

/** A-01: email and password, then the 6-digit code from the authenticator app. 5 misses lock it for 15 minutes. */
export async function signIn(prev: LoginState, form: FormData): Promise<LoginState> {
  const jar = await cookies();
  if (prev?.step === "code") {
    const challenge = jar.get(CHALLENGE)?.value;
    if (!challenge) return { step: "password", error: "처음부터 다시 로그인해 주세요." };
    try {
      const r = await totp(challenge, String(form.get("code") ?? "").replace(/\D/g, ""));
      const maxAge = Math.max(60, Math.round((new Date(r.expires_at).getTime() - Date.now()) / 1000));
      jar.set(TOKEN, r.token, cookieOptions(maxAge));
      jar.set(OPERATOR, JSON.stringify(r.operator), cookieOptions(maxAge));
      jar.set(CHALLENGE, "", cookieOptions(0));
    } catch (e) {
      if (e instanceof ApiError) {
        // invalid_code comes with a fresh challenge; an expired one starts over.
        if (typeof e.data.challenge === "string") jar.set(CHALLENGE, e.data.challenge, cookieOptions(300));
        if (e.code === "expired" || e.code === "challenge_expired") return { step: "password", error: "처음부터 다시 로그인해 주세요." };
        if (e.status === 423) return { step: "password", error: "로그인 시도가 많아 잠겼어요. 15분 뒤에 다시 해 주세요." };
        return { step: "code", error: "인증 코드가 맞지 않아요." };
      }
      throw e;
    }
    redirect("/reports");
  }
  try {
    const { challenge } = await login(String(form.get("email") ?? "").trim(), String(form.get("password") ?? ""));
    jar.set(CHALLENGE, challenge, cookieOptions(300));
    return { step: "code" };
  } catch (e) {
    if (e instanceof ApiError) {
      if (e.status === 423) return { step: "password", error: `로그인 시도가 많아 잠겼어요. ${lockedUntil(e) ?? "15분 뒤"}부터 다시 할 수 있어요.` };
      return { step: "password", error: "이메일이나 비밀번호가 맞지 않아요." };
    }
    throw e;
  }
}

export async function signOut() {
  const s = await session();
  if (s) await logout(s.token);
  const jar = await cookies();
  for (const n of [TOKEN, OPERATOR, CHALLENGE]) jar.set(n, "", cookieOptions(0));
  redirect("/login");
}
