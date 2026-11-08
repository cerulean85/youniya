import { NextResponse, type NextRequest } from "next/server";
import { publicApi } from "@/lib/api";
import { clearTokens, REFRESH } from "@/lib/session";

export async function POST(request: NextRequest) {
  const refresh = request.cookies.get(REFRESH)?.value;
  if (refresh) await publicApi("/v1/auth/logout", { refresh_token: refresh }).catch(() => null);
  const res = NextResponse.redirect(new URL("/login", request.url), 303);
  clearTokens(res.cookies);
  return res;
}
