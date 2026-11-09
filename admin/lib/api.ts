import "server-only";
import { redirect } from "next/navigation";
import { API_URL, live, MOCK, type Part } from "./config";
import * as mock from "./mock";
import * as more from "./mock-more";
import * as own from "./mock-owner";
import { session } from "./session";
import type { ActionKind, AiUsage, AuditEntry, Dashboard, InquiryDetail, Invites, Ledger, Notices, OperatorRow, Prism, Range, InquiryRow, InquiryStatus, KeeperAction, KeeperDetail, KeeperRow, Operator, ReportDetail, ReportItem, ReportKind, ReportStatus } from "./types";

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
  if (live("auth")) mock.adopt(s.token, s.operator); // mock-backed screens under a real session
  return s.token;
}
async function guard<T>(f: () => T): Promise<T> {
  try { return m(f); } catch (e) {
    if (e instanceof ApiError && e.status === 401) redirect("/login?expired=1");
    throw e;
  }
}

export const isMock = MOCK;
export const authIsLive = live("auth");

export async function login(email: string, password: string): Promise<{ challenge: string }> {
  return !live("auth") ? m(() => mock.login(email, password)) : call("/v1/admin/auth/login", { method: "POST", body: JSON.stringify({ email, password }) });
}

export async function totp(challenge: string, code: string): Promise<{ token: string; expires_at: string; operator: Operator }> {
  return !live("auth") ? m(() => mock.totp(challenge, code)) : call("/v1/admin/auth/totp", { method: "POST", body: JSON.stringify({ challenge, code }) });
}

export async function logout(t: string) {
  if (!live("auth")) return mock.logout(t);
  await call("/v1/admin/auth/logout", { method: "POST" }, t).catch(() => null);
}

export async function listReports(status?: ReportStatus): Promise<{ items: ReportItem[]; counts?: Record<ReportStatus, number> }> {
  if (!live("reports")) { const t = await token(); return guard(() => mock.listReports(t, status)); }
  return authed(`/v1/admin/reports${status ? `?status=${status}` : ""}`);
}

export async function getReport(kind: ReportKind, id: string): Promise<ReportDetail> {
  if (!live("reports")) { const t = await token(); return guard(() => mock.getReport(t, kind, id)); }
  return authed(`/v1/admin/reports/${kind}/${encodeURIComponent(id)}`);
}

export async function act(kind: ReportKind, id: string, action: ActionKind, reason: string, note?: string) {
  if (!live("reports")) { const t = await token(); return guard(() => mock.act(t, kind, id, action, reason, note)); }
  return authed<{ status: ReportStatus; action_id: string }>(`/v1/admin/reports/${kind}/${encodeURIComponent(id)}/actions`,
    { method: "POST", body: JSON.stringify({ action, reason, note }) });
}

export async function audit(): Promise<AuditEntry[]> {
  if (!live("audit")) { const t = await token(); return guard(() => mock.audit(t)); }
  return (await authed<{ items: AuditEntry[] }>("/v1/admin/audit?format=json")).items;
}

// ── 별지기 (A-05, A-06) and 문의 (A-07): the shape proposed to the API Dev Session ──


export async function listKeepers(q = "", filter = "all"): Promise<KeeperRow[]> {
  if (!live("keepers")) { const t = await token(); return guard(() => more.listKeepers(t, q, filter)); }
  return (await authed<{ items: KeeperRow[] }>(`/v1/admin/keepers?${new URLSearchParams({ q, filter })}`)).items;
}

export async function keepersCsv(): Promise<string> {
  if (!live("keepers")) { const t = await token(); return guard(() => more.keepersCsv(t)); }
  const s = await session();
  if (!s) redirect("/login");
  const res = await fetch(`${API_URL}/v1/admin/keepers?format=csv`, { headers: { Authorization: `Bearer ${s.token}` }, cache: "no-store" });
  if (!res.ok) throw new ApiError(res.status, "error", "내보내지 못했어요.");
  return res.text();
}

export async function getKeeper(id: string): Promise<KeeperDetail> {
  if (!live("keepers")) { const t = await token(); return guard(() => more.getKeeper(t, id)); }
  return authed(`/v1/admin/keepers/${encodeURIComponent(id)}`);
}

export async function keeperAction(id: string, action: KeeperAction, reason: string, amount?: number, days?: number) {
  if (!live("keepers")) { const t = await token(); return guard(() => more.keeperAction(t, id, action, reason, amount, days)); }
  return authed(`/v1/admin/keepers/${encodeURIComponent(id)}/actions`, { method: "POST", body: JSON.stringify({ action, reason, amount, days }) });
}

export async function listInquiries(status: InquiryStatus): Promise<{ items: InquiryRow[]; counts?: Record<InquiryStatus, number> }> {
  if (!live("inquiries")) { const t = await token(); return guard(() => more.listInquiries(t, status)); }
  return authed(`/v1/admin/inquiries?status=${status}`);
}

export async function getInquiry(id: string): Promise<InquiryDetail> {
  if (!live("inquiries")) { const t = await token(); return guard(() => more.getInquiry(t, id)); }
  return authed(`/v1/admin/inquiries/${encodeURIComponent(id)}`);
}

export async function replyInquiry(id: string, body: string) {
  if (!live("inquiries")) { const t = await token(); return guard(() => more.reply(t, id, body)); }
  return authed(`/v1/admin/inquiries/${encodeURIComponent(id)}/reply`, { method: "POST", body: JSON.stringify({ body }) });
}

// ── Owner screens (A-02, A-08~A-12, A-14): proposed shapes, owners only (403 forbidden_role otherwise) ──

const post = (body: unknown) => ({ method: "POST", body: JSON.stringify(body) });
const put = (body: unknown) => ({ method: "PUT", body: JSON.stringify(body) });
const patch = (body: unknown) => ({ method: "PATCH", body: JSON.stringify(body) });
async function owned<T>(f: (t: string) => T, path: string, init?: RequestInit, part: Part = "owner"): Promise<T> {
  if (!live(part)) { const t = await token(); return guard(() => f(t)); }
  return authed<T>(path, init);
}

export const getDashboard = (range: Range) => owned<Dashboard>((t) => own.dashboard(t, range), `/v1/admin/dashboard?range=${range}`);
export const getLedger = (month: string) => owned<Ledger>((t) => own.ledger(t, month), `/v1/admin/coins?month=${month}`);
export const getAi = (month: string) => owned<AiUsage>((t) => own.ai(t, month), `/v1/admin/ai?month=${month}`);
export const getPrism = () => owned<Prism>((t) => own.prism(t), "/v1/admin/prism");
export const testPrism = (key: string, reason: string) => owned((t) => own.prismTest(t, key, reason), `/v1/admin/prism/${key}/test`, post({ reason }));
export const deployPrism = (key: string, reason: string) => owned((t) => own.prismDeploy(t, key, reason), `/v1/admin/prism/${key}/deploy`, post({ reason }));
export const getInvites = () => owned<Invites>((t) => own.invites(t), "/v1/admin/invites");
export const setInvitesEnabled = (on: boolean, reason: string) => owned((t) => own.invitesEnabled(t, on, reason), "/v1/admin/invites/settings", put({ enabled: on, reason }));
export const createInvite = (loginId: string, memo: string, reason: string) =>
  owned<{ password: string }>((t) => own.createInvite(t, loginId, memo, reason), "/v1/admin/invites", post({ login_id: loginId, memo, reason }));
export const setInvite = (id: string, on: boolean, reason: string) => owned((t) => own.setInvite(t, id, on, reason), `/v1/admin/invites/${id}`, patch({ enabled: on, reason }));
export const reseedInvite = (id: string, reason: string) => owned((t) => own.reseed(t, id, reason), `/v1/admin/invites/${id}/reseed`, post({ reason }));
export const getNotices = () => owned<Notices>((t) => own.notices(t), "/v1/admin/notices");
export const setMaintenance = (on: boolean, reason: string) => owned((t) => own.setMaintenance(t, on, reason), "/v1/admin/maintenance", put({ on, reason }));
export const setMinVersion = (ios: string, reason: string) => owned((t) => own.setMinVersion(t, ios, reason), "/v1/admin/min-version", put({ ios, reason }));
export const createNotice = (n: { title: string; body: string; audience: "all" | "ios" | "web"; starts_at: string; ends_at: string }, reason: string) =>
  owned((t) => own.createNotice(t, n, reason), "/v1/admin/notices", post({ ...n, reason }));
type RealOperator = { id: string; email: string; role: "owner" | "moderator"; status: string; totp: boolean; last_seen_at: string | null; created_at: string };
const mask = (email: string) => { const [u, d] = email.split("@"); return `${u.slice(0, 1)}●●●@${d ?? ""}`; };
const toRow = (o: RealOperator): OperatorRow => ({
  id: o.id, name: o.email.split("@")[0], email_masked: mask(o.email), role: o.role, totp: o.totp, last_seen_at: o.last_seen_at,
  status: o.status === "disabled" ? "disabled" : o.totp ? "active" : "invited",
});
export const getOperators = async (): Promise<OperatorRow[]> =>
  !live("operators") ? owned((t) => own.operators(t), "") : (await authed<{ items: RealOperator[] }>("/v1/admin/operators")).items.map(toRow);
/** An invitation gives a one-time setup token (3 days); the console shows the setup link once. */
export const inviteOperator = async (email: string, role: "owner" | "moderator", reason: string): Promise<{ setup_token?: string; expires_at?: string }> =>
  !live("operators") ? owned((t) => own.inviteOperator(t, email, role, reason), "") : authed("/v1/admin/operators/invite", post({ email, role, reason }));
export const updateOperator = (id: string, p: { role?: "owner" | "moderator"; status?: "active" | "disabled" }, reason: string) =>
  owned((t) => own.updateOperator(t, id, p, reason), `/v1/admin/operators/${id}`, patch({ ...p, reason }), "operators");

/** /setup: an invited operator sets a password, then the authenticator app. */
export const setupPassword = (inviteToken: string, password: string) =>
  call<{ totp_secret: string; otpauth_uri: string }>("/v1/admin/auth/setup", post({ invite_token: inviteToken, password }));
export const setupConfirm = (inviteToken: string, code: string) =>
  call<{ operator: RealOperator } | RealOperator>("/v1/admin/auth/setup/confirm", post({ invite_token: inviteToken, code }));
