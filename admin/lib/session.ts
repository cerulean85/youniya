import "server-only";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import type { Operator, Role } from "./types";

// The console's own cookies, on admin.youniya.dycdyp.com only (the user web app's yn_* never come here).
export const TOKEN = "adm_t";
export const OPERATOR = "adm_op";
export const CHALLENGE = "adm_ch";

export const cookieOptions = (maxAge: number) => ({
  httpOnly: true, secure: process.env.NODE_ENV === "production", sameSite: "strict" as const, path: "/", maxAge,
});

export async function session(): Promise<{ token: string; operator: Operator } | null> {
  const jar = await cookies();
  const token = jar.get(TOKEN)?.value, op = jar.get(OPERATOR)?.value;
  if (!token || !op) return null;
  try { return { token, operator: JSON.parse(op) as Operator }; } catch { return null; }
}

/** Signed in, and allowed here: owners everywhere, moderators only where `roles` lets them. */
export async function requireOperator(roles: Role[] = ["owner", "moderator"]) {
  const s = await session();
  if (!s) redirect("/login");
  if (!roles.includes(s.operator.role)) redirect("/forbidden");
  return s;
}
