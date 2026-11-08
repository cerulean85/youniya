import "server-only";

// The API's tokens, kept in httpOnly cookies on the web app's own domain.
export const ACCESS = "yn_at";
export const REFRESH = "yn_rt";
export const ACCESS_MAX_AGE = 60 * 60; // server ACCESS_TTL
export const REFRESH_MAX_AGE = 60 * 60 * 24 * 30; // server REFRESH_TTL

export const cookieOptions = (maxAge: number) => ({
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "lax" as const,
  path: "/",
  maxAge,
});

export type Tokens = { access_token: string; refresh_token: string; needs_consent?: boolean };

type CookieJar = { set: (name: string, value: string, options: ReturnType<typeof cookieOptions>) => unknown };

export function storeTokens(jar: CookieJar, t: Tokens) {
  jar.set(ACCESS, t.access_token, cookieOptions(ACCESS_MAX_AGE));
  jar.set(REFRESH, t.refresh_token, cookieOptions(REFRESH_MAX_AGE));
}

export function clearTokens(jar: CookieJar) {
  jar.set(ACCESS, "", cookieOptions(0));
  jar.set(REFRESH, "", cookieOptions(0));
}
