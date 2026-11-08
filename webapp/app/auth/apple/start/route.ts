import { randomBytes } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";
import { APPLE_REDIRECT_URI, APPLE_SERVICES_ID } from "@/lib/config";

// Sign in with Apple, redirect flow. No name or email is asked for: the API keeps only Apple's subject.
// Apple posts back cross-site, so the state/nonce cookie must be SameSite=None (HTTPS only).
export async function GET(request: NextRequest) {
  const state = randomBytes(16).toString("base64url");
  const nonce = randomBytes(16).toString("base64url");
  const url = new URL("https://appleid.apple.com/auth/authorize");
  url.search = new URLSearchParams({
    client_id: APPLE_SERVICES_ID,
    redirect_uri: APPLE_REDIRECT_URI,
    response_type: "code id_token",
    response_mode: "form_post",
    state,
    nonce,
  }).toString();
  const res = NextResponse.redirect(url);
  const next = request.nextUrl.searchParams.get("next") ?? "";
  res.cookies.set("yn_apple", JSON.stringify({ state, nonce, next }), {
    httpOnly: true, secure: true, sameSite: "none", path: "/auth/apple", maxAge: 600,
  });
  return res;
}
