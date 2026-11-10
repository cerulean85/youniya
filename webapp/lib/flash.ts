import "server-only";
import { cookies } from "next/headers";

/** W-89 토스트: a short message for the next render (components/Flash shows it once, then clears it). */
export async function flash(title: string, sub?: string) {
  (await cookies()).set("yn_flash", encodeURIComponent(JSON.stringify([title, sub ?? "", Date.now()])), { path: "/", maxAge: 30, sameSite: "lax" });
}

export async function readFlash(): Promise<{ title: string; sub: string; at: number } | null> {
  const raw = (await cookies()).get("yn_flash")?.value;
  if (!raw) return null;
  try { const [title, sub, at] = JSON.parse(decodeURIComponent(raw)); return { title, sub, at }; } catch { return null; }
}
