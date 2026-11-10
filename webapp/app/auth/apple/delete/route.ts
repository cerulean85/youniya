import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";
import { API_URL, APPLE_REDIRECT_URI, APPLE_SERVICES_ID } from "@/lib/config";
import { ACCESS, clearTokens } from "@/lib/session";

// The second half of 계정 영구 삭제 for an Apple account: DELETE /v1/me with Apple's code, so the server revokes
// the Apple tokens and then deletes. 400 apple_reauth_required keeps the account; the person can try again.
export async function GET(request: NextRequest) {
  const jar = await cookies();
  const code = jar.get("yn_apple_del")?.value;
  const token = jar.get(ACCESS)?.value;
  const go = (path: string) => {
    const res = NextResponse.redirect(new URL(path, request.url), 303);
    res.cookies.set("yn_apple_del", "", { path: "/auth/apple", maxAge: 0 });
    return res;
  };
  if (!token) return go("/login");
  if (!code) return go("/settings?delete=failed");
  const res = await fetch(`${API_URL}/v1/me`, {
    method: "DELETE", cache: "no-store",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ apple_authorization_code: code, apple_client_id: APPLE_SERVICES_ID, apple_redirect_uri: APPLE_REDIRECT_URI }),
  }).catch(() => null);
  if (!res?.ok) {
    const err = res ? ((await res.json().catch(() => null))?.error ?? {}) : {};
    return go(`/settings?delete=${err.code === "apple_reauth_required" ? "retry" : "failed"}`);
  }
  const out = go("/deleted");
  clearTokens(out.cookies);
  return out;
}
