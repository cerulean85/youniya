import "server-only";
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { API_URL } from "./config";
import { ACCESS } from "./session";

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public data: Record<string, unknown> = {}) {
    super(message);
  }
}

/** Calls the YOUNIYA API as the signed-in person. proxy.ts keeps the access token fresh. */
export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = (await cookies()).get(ACCESS)?.value;
  if (!token) redirect("/login");
  const res = await fetch(`${API_URL}${path}`, {
    ...init,
    cache: "no-store",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, ...init.headers },
  });
  if (res.status === 401) redirect("/expired"); // W-87
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const err = data?.error ?? {};
    if (err.code === "consent_required") redirect("/welcome");
    // 41 잠시 점검 중이에요: the server is in maintenance (operators switch it from the console).
    if (res.status === 503 && err.code === "maintenance") redirect(`/maintenance${err.until ? `?until=${encodeURIComponent(err.until)}` : ""}`);
    // W-88 잠시 숨을 고르고 있어요: too many requests; back to this screen once retry_after has passed.
    // Only throttling (rate_limited, or a 429 from in front of the API without our body): unlit_daily_limit and
    // nickname_too_soon are 429s too, and the screen that asked says those itself.
    if (res.status === 429 && (!err.code || err.code === "rate_limited")) {
      const after = Number(err.retry_after ?? res.headers.get("Retry-After")) || 60;
      const back = (await headers()).get("x-yn-path") ?? "/";
      redirect(`/busy?${new URLSearchParams({ after: String(after), back })}`);
    }
    throw new ApiError(res.status, err.code ?? "error", err.message ?? "잠시 뒤에 다시 시도해 주세요.", err);
  }
  return data as T;
}

/** Calls the API without a session (sign-in, refresh). */
export async function publicApi<T>(path: string, body: unknown): Promise<{ ok: boolean; status: number; data: T }> {
  const res = await fetch(`${API_URL}${path}`, {
    method: "POST",
    cache: "no-store",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  return { ok: res.ok, status: res.status, data: text ? JSON.parse(text) : null };
}
