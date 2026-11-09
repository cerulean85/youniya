"use server";

import { redirect } from "next/navigation";
import QRCode from "qrcode";
import { ApiError, setupConfirm, setupPassword } from "@/lib/api";

export type SetupState = { step: "password" | "totp"; error?: string; qr?: string; secret?: string } | null;

const ERRORS: Record<string, string> = {
  invalid_invite: "초대 링크가 맞지 않거나 이미 쓰였어요. 초대한 운영자에게 새 링크를 받아 주세요.",
  invite_expired: "초대 링크가 만료됐어요(3일). 새 링크를 받아 주세요.",
  weak_password: "비밀번호는 12자 이상으로 정해 주세요.",
  invalid_code: "인증 코드가 맞지 않아요. 앱에 보이는 새 코드를 넣어 주세요.",
};

/** A-14 초대 → 설정: a password of 12 or more, then the authenticator app (QR), confirmed with one code. */
export async function setup(prev: SetupState, form: FormData): Promise<SetupState> {
  const token = String(form.get("token") ?? "");
  if (prev?.step === "totp") {
    try {
      await setupConfirm(token, String(form.get("code") ?? "").replace(/\D/g, ""));
    } catch (e) {
      if (e instanceof ApiError) return { ...prev, error: ERRORS[e.code] ?? e.message };
      throw e;
    }
    redirect("/login?setup=1");
  }
  const password = String(form.get("password") ?? "");
  if (password.length < 12) return { step: "password", error: ERRORS.weak_password };
  if (password !== String(form.get("confirm") ?? "")) return { step: "password", error: "두 비밀번호가 달라요." };
  try {
    const r = await setupPassword(token, password);
    const qr = await QRCode.toString(r.otpauth_uri, { type: "svg", margin: 1, color: { dark: "#0b0f19", light: "#ffffff" } });
    return { step: "totp", qr, secret: r.totp_secret };
  } catch (e) {
    if (e instanceof ApiError) return { step: "password", error: ERRORS[e.code] ?? e.message };
    throw e;
  }
}
