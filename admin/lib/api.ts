import "server-only";
import { redirect } from "next/navigation";
import { API_URL, MOCK } from "./config";
import * as mock from "./mock";
import { session } from "./session";
import type { ActionKind, AuditEntry, Operator, ReportDetail, ReportItem, ReportKind, ReportStatus } from "./types";

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public data: Record<string, unknown> = {}) { super(message); }
}

async function call<T>(path: string, init: RequestInit = {}, token?: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    ...init, cache: "no-store",
    headers: { "Content-Type": "application/json", ...(token && { Authorization: `Bearer ${token}` }), ...init.headers },
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const err = data?.error ?? {};
    throw new ApiError(res.status, err.code ?? "error", err.message ?? "잠시 뒤에 다시 시도해 주세요.", err);
  }
  return data as T;
}

/** Runs a mock call the same way: MockError becomes ApiError. */
function m<T>(f: () => T): T {
  try { return f(); } catch (e) {
    if (e instanceof mock.MockError) throw new ApiError(e.status, e.code, e.message, e.data);
    throw e;
  }
}

async function authed<T>(path: string, init: RequestInit = {}): Promise<T> {
  const s = await session();
  if (!s) redirect("/login");
  try { return await call<T>(path, init, s.token); } catch (e) {
    if (e instanceof ApiError && e.status === 401) redirect("/login?expired=1");
    throw e;
  }
}
async function token() {
  const s = await session();
  if (!s) redirect("/login");
  return s.token;
}
async function guard<T>(f: () => T): Promise<T> {
  try { return m(f); } catch (e) {
    if (e instanceof ApiError && e.status === 401) redirect("/login?expired=1");
    throw e;
  }
}

export const isMock = MOCK;

export async function login(email: string, password: string): Promise<{ challenge: string }> {
  return MOCK ? m(() => mock.login(email, password)) : call("/v1/admin/auth/login", { method: "POST", body: JSON.stringify({ email, password }) });
}

export async function totp(challenge: string, code: string): Promise<{ token: string; expires_at: string; operator: Operator }> {
  return MOCK ? m(() => mock.totp(challenge, code)) : call("/v1/admin/auth/totp", { method: "POST", body: JSON.stringify({ challenge, code }) });
}

export async function logout(t: string) {
  if (MOCK) return mock.logout(t);
  await call("/v1/admin/auth/logout", { method: "POST" }, t).catch(() => null);
}

export async function listReports(status?: ReportStatus): Promise<{ items: ReportItem[]; counts?: Record<ReportStatus, number> }> {
  if (MOCK) { const t = await token(); return guard(() => mock.listReports(t, status)); }
  return authed(`/v1/admin/reports${status ? `?status=${status}` : ""}`);
}

export async function getReport(kind: ReportKind, id: string): Promise<ReportDetail> {
  if (MOCK) { const t = await token(); return guard(() => mock.getReport(t, kind, id)); }
  return authed(`/v1/admin/reports/${kind}/${encodeURIComponent(id)}`);
}

export async function act(kind: ReportKind, id: string, action: ActionKind, reason: string, note?: string) {
  if (MOCK) { const t = await token(); return guard(() => mock.act(t, kind, id, action, reason, note)); }
  return authed<{ status: ReportStatus; action_id: string }>(`/v1/admin/reports/${kind}/${encodeURIComponent(id)}/actions`,
    { method: "POST", body: JSON.stringify({ action, reason, note }) });
}

export async function audit(): Promise<AuditEntry[]> {
  if (MOCK) { const t = await token(); return guard(() => mock.audit(t)); }
  return (await authed<{ items: AuditEntry[] }>("/v1/admin/audit?format=json")).items;
}
