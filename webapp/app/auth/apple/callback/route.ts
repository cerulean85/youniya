import { NextResponse, type NextRequest } from "next/server";
import { claims, finishSignIn, storeTokens } from "@/lib/signin";

// Apple posts { state, code, id_token } here. The state and nonce must be the ones /auth/apple/start set.
export async function POST(request: NextRequest) {
  const form = await request.formData();
  let saved: { state?: string; nonce?: string; next?: string; purpose?: string } = {};
  try { saved = JSON.parse(request.cookies.get("yn_apple")?.value ?? "{}"); } catch { /* treated as missing */ }
  if (saved.purpose === "delete") return forDeletion(request, form, saved);
  const fail = () => {
    const res = NextResponse.redirect(new URL("/login?error=signin", request.url), 303);
    res.cookies.set("yn_apple", "", { path: "/auth/apple", maxAge: 0 });
    return res;
  };
  if (form.get("error")) return fail(); // the person cancelled
  const idToken = String(form.get("id_token") ?? "");
  if (!idToken || !saved.state || form.get("state") !== saved.state || claims(idToken).nonce !== saved.nonce) return fail();

  const done = await finishSignIn("apple", idToken, request.url, saved.next);
  if (!done.ok) return fail();
  const res = NextResponse.redirect(new URL(done.to, request.url), 303);
  storeTokens(res.cookies, done.tokens);
  res.cookies.set("yn_apple", "", { path: "/auth/apple", maxAge: 0 });
  return res;
}

// 계정 삭제의 Apple 본인 확인: Apple posts cross-site, so the session cookie (SameSite=Lax) isn't here. The code
// waits in a short cookie and a same-site GET (/auth/apple/delete) sends it with the session. Closing Apple's
// page deletes nothing.
function forDeletion(request: NextRequest, form: FormData, saved: { state?: string; nonce?: string }) {
  const to = (path: string) => {
    const res = NextResponse.redirect(new URL(path, request.url), 303);
    res.cookies.set("yn_apple", "", { path: "/auth/apple", maxAge: 0 });
    return res;
  };
  const code = String(form.get("code") ?? "");
  const idToken = String(form.get("id_token") ?? "");
  if (form.get("error") || !code) return to("/settings?delete=cancel");
  if (!saved.state || form.get("state") !== saved.state || !idToken || claims(idToken).nonce !== saved.nonce) return to("/settings?delete=failed");
  const res = to("/auth/apple/delete");
  res.cookies.set("yn_apple_del", code, { httpOnly: true, secure: true, sameSite: "lax", path: "/auth/apple", maxAge: 300 });
  return res;
}
