"use server";

import { headers } from "next/headers";
import { api, ApiError } from "@/lib/api";

export type InquiryState = { error?: string; ok?: boolean } | null;
const KINDS = ["payment", "account", "other"] as const;
/** The deployed build: the commit on Vercel, the package version locally. */
const WEB_VERSION = process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) || process.env.npm_package_version || "0.1.0";

/** "Chrome 141 · macOS" from the User-Agent, for the operators' A-07 (no other browser data). */
function device(ua: string) {
  const browser = /Edg\/(\d+)/.exec(ua) ? `Edge ${/Edg\/(\d+)/.exec(ua)![1]}` : /Chrome\/(\d+)/.exec(ua) ? `Chrome ${/Chrome\/(\d+)/.exec(ua)![1]}`
    : /Firefox\/(\d+)/.exec(ua) ? `Firefox ${/Firefox\/(\d+)/.exec(ua)![1]}` : /Version\/(\d+).*Safari/.exec(ua) ? `Safari ${/Version\/(\d+)/.exec(ua)![1]}` : "브라우저";
  const os = /Mac OS X/.test(ua) ? "macOS" : /Windows/.test(ua) ? "Windows" : /Android/.test(ua) ? "Android" : /iPhone|iPad/.test(ua) ? "iOS" : /Linux/.test(ua) ? "Linux" : "";
  return os ? `${browser} · ${os}` : browser;
}

/** W-19 문의하기: the reply goes to the email given here (Resend). */
export async function sendInquiry(_p: InquiryState, form: FormData): Promise<InquiryState> { void _p;
  const kind = KINDS.find((k) => k === form.get("kind")) ?? "other";
  const email = String(form.get("email") ?? "").trim();
  const body = String(form.get("body") ?? "").trim();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { error: "답장 받을 이메일을 확인해 주세요." };
  if (!body) return { error: "문의 내용을 적어 주세요." };
  const h = await headers();
  try {
    await api("/v1/inquiries", {
      method: "POST", body: JSON.stringify({ kind, email, body }),
      // The server checks the minimum version for iOS only; web passes with any version.
      headers: { "X-App-Platform": "web", "X-App-Version": WEB_VERSION, "X-Device-Model": device(h.get("user-agent") ?? "") },
    });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message };
    throw e;
  }
  return { ok: true };
}
