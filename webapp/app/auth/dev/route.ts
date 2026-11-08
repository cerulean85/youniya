import { NextResponse, type NextRequest } from "next/server";
import { publicApi } from "@/lib/api";
import { DEV_LOGIN } from "@/lib/config";
import { storeTokens, type Tokens } from "@/lib/session";

// Local development only: the API's DEV_LOGIN sign-in. The same name is always the same account.
export async function POST(request: NextRequest) {
  if (!DEV_LOGIN) return new NextResponse(null, { status: 404 });
  const form = await request.formData();
  const name = String(form.get("name") ?? "").trim() || "web-dev";
  const r = await publicApi<Tokens>("/v1/auth/dev", { name });
  if (!r.ok) return NextResponse.redirect(new URL("/login?error=1", request.url), 303);
  const next = String(form.get("next") ?? "");
  const to = r.data.needs_consent ? "/welcome" : next.startsWith("/") && !next.startsWith("//") ? next : "/";
  const res = NextResponse.redirect(new URL(to, request.url), 303);
  storeTokens(res.cookies, r.data);
  return res;
}
