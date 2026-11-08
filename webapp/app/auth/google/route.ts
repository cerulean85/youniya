import { NextResponse, type NextRequest } from "next/server";
import { finishSignIn, storeTokens } from "@/lib/signin";

// Google Identity Services hands the browser an ID token (aud = our web client ID); the browser posts
// it here, and the API verifies it against GOOGLE_CLIENT_IDS.
export async function POST(request: NextRequest) {
  const { credential, next } = (await request.json().catch(() => ({}))) as { credential?: string; next?: string };
  if (!credential) return NextResponse.json({ error: "missing credential" }, { status: 400 });
  const done = await finishSignIn("google", credential, request.url, next);
  if (!done.ok) return NextResponse.json({ error: "signin" }, { status: 401 });
  const res = NextResponse.json({ to: done.to });
  storeTokens(res.cookies, done.tokens);
  return res;
}
