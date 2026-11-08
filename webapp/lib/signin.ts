import "server-only";
import { NextResponse } from "next/server";
import { publicApi } from "./api";
import { storeTokens, type Tokens } from "./session";

/** Exchanges an Apple or Google ID token for the API's session and stores it in cookies. */
export async function finishSignIn(provider: "apple" | "google", idToken: string, base: string, next?: string | null) {
  const r = await publicApi<Tokens>(`/v1/auth/${provider}`, { id_token: idToken });
  if (!r.ok) return { ok: false as const, response: NextResponse.redirect(new URL("/login?error=signin", base), 303) };
  const safeNext = next && next.startsWith("/") && !next.startsWith("//") ? next : "/";
  const to = r.data.needs_consent ? "/welcome" : safeNext;
  return { ok: true as const, to, tokens: r.data };
}

export { storeTokens };

/** The payload of a JWT, unverified. Only for comparing our own nonce; the API verifies signatures. */
export function claims(jwt: string): Record<string, unknown> {
  try {
    return JSON.parse(Buffer.from(jwt.split(".")[1], "base64url").toString("utf8"));
  } catch {
    return {};
  }
}
