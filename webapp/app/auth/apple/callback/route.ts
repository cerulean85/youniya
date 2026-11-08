import { NextResponse, type NextRequest } from "next/server";
import { claims, finishSignIn, storeTokens } from "@/lib/signin";

// Apple posts { state, code, id_token } here. The state and nonce must be the ones /auth/apple/start set.
export async function POST(request: NextRequest) {
  const form = await request.formData();
  const fail = () => {
    const res = NextResponse.redirect(new URL("/login?error=signin", request.url), 303);
    res.cookies.set("yn_apple", "", { path: "/auth/apple", maxAge: 0 });
    return res;
  };
  if (form.get("error")) return fail(); // the person cancelled
  const idToken = String(form.get("id_token") ?? "");
  let saved: { state?: string; nonce?: string; next?: string } = {};
  try { saved = JSON.parse(request.cookies.get("yn_apple")?.value ?? "{}"); } catch { /* treated as missing */ }
  if (!idToken || !saved.state || form.get("state") !== saved.state || claims(idToken).nonce !== saved.nonce) return fail();

  const done = await finishSignIn("apple", idToken, request.url, saved.next);
  if (!done.ok) return fail();
  const res = NextResponse.redirect(new URL(done.to, request.url), 303);
  storeTokens(res.cookies, done.tokens);
  res.cookies.set("yn_apple", "", { path: "/auth/apple", maxAge: 0 });
  return res;
}
