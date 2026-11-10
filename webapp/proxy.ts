import { NextResponse, type NextRequest } from "next/server";

// Runs before every app screen. Signed out: to /login. Access token missing or about to expire:
// rotate it with the refresh token, and hand the new one both to this render and to the browser.
const ACCESS = "yn_at";
const REFRESH = "yn_rt";
const API_URL = process.env.YOUNIYA_API_URL ?? "https://youniya-api.dycdyp.com";
const PUBLIC = ["/login", "/auth/", "/maintenance", "/deleted", "/expired"];

function expiresSoon(jwt: string | undefined) {
  if (!jwt) return true;
  try {
    const payload = JSON.parse(atob(jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    return typeof payload.exp !== "number" || payload.exp * 1000 < Date.now() + 60_000;
  } catch {
    return true;
  }
}

/** Signed out: to /login. A session that could no longer refresh: W-87 다시 로그인해 주세요 first. */
function toLogin(request: NextRequest, expired = false) {
  const url = new URL(expired ? "/expired" : "/login", request.url);
  const next = request.nextUrl.pathname + request.nextUrl.search;
  if (next !== "/") url.searchParams.set("next", next);
  const res = NextResponse.redirect(url);
  res.cookies.delete(ACCESS);
  res.cookies.delete(REFRESH);
  return res;
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (PUBLIC.some((p) => pathname === p || pathname.startsWith(p))) return NextResponse.next();

  const refresh = request.cookies.get(REFRESH)?.value;
  if (!refresh) return toLogin(request);
  // The screen being shown, for W-88's '다시 시도' after a 429 (lib/api).
  request.headers.set("x-yn-path", request.nextUrl.pathname + request.nextUrl.search);
  if (!expiresSoon(request.cookies.get(ACCESS)?.value)) return NextResponse.next({ request: { headers: request.headers } });

  const r = await fetch(`${API_URL}/v1/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: refresh }),
    cache: "no-store",
  }).catch(() => null);
  if (!r?.ok) return toLogin(request, Boolean(r && r.status === 401));
  const t = (await r.json()) as { access_token: string; refresh_token: string };

  request.cookies.set(ACCESS, t.access_token);
  request.cookies.set(REFRESH, t.refresh_token);
  const res = NextResponse.next({ request: { headers: request.headers } });
  const secure = process.env.NODE_ENV === "production";
  res.cookies.set(ACCESS, t.access_token, { httpOnly: true, secure, sameSite: "lax", path: "/", maxAge: 60 * 60 });
  res.cookies.set(REFRESH, t.refresh_token, { httpOnly: true, secure, sameSite: "lax", path: "/", maxAge: 60 * 60 * 24 * 30 });
  return res;
}

export const config = {
  // App screens only: not Next internals, icons or the public star tile.
  matcher: ["/((?!_next/|icon|apple-icon|stars\\.svg|favicon).*)"],
};
