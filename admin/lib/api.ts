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

// The API's owner shapes (server/docs/admin_api_plan.md, step 7-3) turned into what the screens show.
/* eslint-disable @typescript-eslint/no-explicit-any */
const ALERT: Record<string, [string, Dashboard["events"][number]["status"]]> = {
  report_instant: ["개인정보·자해 신고 · 바로 숨겼어요", "hidden"], report_hidden: ["신고 3건 누적 · 자동으로 숨겼어요", "hidden"],
  ai_cost: ["멤버 원가 경보", "alert"], refund: ["App Store 환불", "done"], nickname_report: ["별지기 이름 신고", "pending"], crisis: ["위기 신호 감지", "ok"],
};
function toDashboard(d: any): Dashboard {
  const n = (v: any) => (typeof v === "number" ? v : v?.count ?? 0);
  return {
    date: d.since ?? new Date().toISOString(),
    stars: { total: d.stars?.total ?? 0, lit: d.stars?.lit ?? 0, unlit: d.stars?.unlit ?? 0 },
    new_keepers: { count: n(d.new_keepers), delta: d.new_keepers?.delta ?? null },
    reports_pending: { count: n(d.reports_pending), overdue: d.reports_pending?.overdue ?? null },
    inquiries_new: { count: n(d.inquiries_new), avg_first_reply_hours: d.inquiries_new?.avg_first_reply_hours ?? null },
    ai_cost_month: { krw: d.ai_cost_month_krw ?? d.ai_cost_month?.krw ?? 0 },
    crisis_stars: d.crisis_stars,
    events: (d.alerts ?? d.events ?? []).map((a: any) => a.text ? a : {
      at: a.at, text: `${ALERT[a.kind]?.[0] ?? a.kind}${a.target_id ? ` · ${a.target_id}` : ""}`, status: ALERT[a.kind]?.[1] ?? "pending",
    }),
    payments_today: d.payments_today ?? { charge_krw: d.payments?.krw_estimate ?? 0, charge_count: d.payments?.count ?? 0, coins: d.payments?.coins },
  };
}
const LEDGER_KIND: Record<string, Ledger["items"][number]["kind"]> = { purchase: "charge", charge: "charge", spend: "use", use: "use", refund: "refund", grant: "grant" };
function toLedger(d: any, month: string): Ledger {
  if (d.summary) return d;
  const t = d.totals ?? {};
  return {
    month: d.month ?? month,
    summary: { charge_krw: t.purchase?.krw_estimate ?? 0, charge_count: t.purchase?.count ?? 0, refund_krw: t.refund?.krw_estimate ?? 0, refund_count: t.refund?.count ?? 0, spend_coins: t.spend?.coins, grant_coins: t.grant?.coins },
    items: (d.items ?? []).map((x: any) => ({
      // keeper_no is a number from the API (null once the account is deleted); the page expects "#4".
      at: x.at, keeper: { id: null, no: x.keeper_no == null ? "탈퇴" : `#${x.keeper_no}`, nickname: null }, kind: LEDGER_KIND[x.kind] ?? "use", detail: x.title ?? x.detail ?? "",
      coins: x.coins, krw_estimate: x.krw_estimate ?? null, reference: x.transaction_id ?? null, source: x.source ?? null,
    })),
  };
}
function toAi(d: any, month: string): AiUsage {
  if (d.summary) return d;
  const f = (k: string) => (d.features ?? []).find((x: any) => x.feature === k);
  const calls = (d.features ?? []).reduce((s: number, x: any) => s + (x.calls ?? 0), 0);
  const attempts = (d.features ?? []).reduce((s: number, x: any) => s + (x.attempts ?? 0), 0);
  const failures = (d.features ?? []).reduce((s: number, x: any) => s + (x.failures ?? 0), 0);
  return {
    month: d.month ?? month, model: d.model ?? null, thinking: d.thinking ?? null, krw_per_usd: d.krw_per_usd ?? null,
    summary: {
      cost_krw: d.total_krw ?? 0, calls, failure_rate: attempts ? Math.round((failures / attempts) * 1000) / 10 : 0,
      per_starlight_krw: Math.round(((f("prism")?.krw_per_request ?? 0) + (f("prism_reading")?.krw_per_request ?? 0)) * 10) / 10,
      cache_hit: f("prism")?.cache_hit_rate != null ? Math.round(f("prism").cache_hit_rate * 100) : null,
      per_telescope_krw: Math.round((f("telescope")?.krw_per_request ?? 0) * 10) / 10,
      member_alerts: (d.over_alert ?? []).length, member_limit_krw: d.alert_krw ?? 2000,
    },
    features: (d.features ?? []).map((x: any) => ({
      feature: x.feature, calls: x.calls ?? x.requests ?? null, attempts: x.attempts, failures: x.failures,
      avg_in: x.avg_input_tokens ?? null, avg_out: x.avg_output_tokens ?? null, cost_krw: x.krw ?? 0,
    })),
    members: (d.over_alert ?? []).map((m: any) => ({ keeper_no: m.keeper_no, nickname: m.nickname, cost_krw: m.krw, alert: true })),
  };
}
function toPrism(d: any): Prism {
  if (d.versions?.[0]?.label) return d;
  const status = (v: any): Prism["versions"][number]["status"] => (v.key === d.current ? "active" : v.status === "draft" || v.status === "held" ? v.status : "retired");
  const t = (d.tests ?? []).at(-1);
  return {
    versions: (d.versions ?? []).map((v: any) => ({
      key: v.key, label: v.key === d.current ? `${v.key} (지금)` : v.key, description: v.description ?? "",
      deployed_at: v.first_at ? String(v.first_at).slice(0, 10) : null, stars: v.stars ?? null, status: status(v),
    })),
    test: t && typeof t.starlight_diff === "number" ? t : null,
  };
}
/* eslint-enable @typescript-eslint/no-explicit-any */

export const getDashboard = async (range: Range) => toDashboard(await owned<unknown>((t) => own.dashboard(t, range), `/v1/admin/dashboard?range=${range}`));
export const getLedger = async (month: string) => toLedger(await owned<unknown>((t) => own.ledger(t, month), `/v1/admin/coins?month=${month}`), month);
export const getAi = async (month: string) => toAi(await owned<unknown>((t) => own.ai(t, month), `/v1/admin/ai?month=${month}`), month);
export const getPrism = async () => toPrism(await owned<unknown>((t) => own.prism(t), "/v1/admin/prism"));
export const testPrism = (key: string, reason: string) => owned((t) => own.prismTest(t, key, reason), `/v1/admin/prism/${key}/test`, post({ reason }));
export const deployPrism = (key: string, reason: string) => owned((t) => own.prismDeploy(t, key, reason), `/v1/admin/prism/${key}/deploy`, post({ reason }));
export const getInvites = async (): Promise<Invites> => {
  const v = await owned<Invites>((t) => own.invites(t), "/v1/admin/invites");
  return { ...v, items: v.items.map((i) => ({ ...i, last_login_at: i.last_login_at ?? (i as { last_seen_at?: string | null }).last_seen_at ?? null })) };
};
export const setInvitesEnabled = (on: boolean, reason: string) => owned((t) => own.invitesEnabled(t, on, reason), "/v1/admin/invites/settings", put({ enabled: on, reason }));
export const createInvite = (loginId: string, memo: string, reason: string) =>
  owned<{ password: string }>((t) => own.createInvite(t, loginId, memo, reason), "/v1/admin/invites", post({ login_id: loginId, memo, reason }));
export const resetInvitePassword = (id: string, reason: string) =>
  owned<{ password: string }>((t) => own.resetInvite(t, id, reason), `/v1/admin/invites/${encodeURIComponent(id)}`, patch({ reset_password: true, reason }));
export const setInvite = (id: string, on: boolean, reason: string) => owned((t) => own.setInvite(t, id, on, reason), `/v1/admin/invites/${encodeURIComponent(id)}`, patch({ enabled: on, reason }));
export const reseedInvite = (id: string, reason: string) => owned((t) => own.reseed(t, id, reason), `/v1/admin/invites/${id}/reseed`, post({ reason }));
export const getNotices = async (): Promise<Notices> => {
  const n = await owned<Notices>((t) => own.notices(t), "/v1/admin/notices");
  const m = n.maintenance as Notices["maintenance"] & { end?: string | null };
  return {
    ...n, maintenance: { on: m.on, until: m.until ?? m.end ?? null },
    items: n.items.map((x) => {
      const p = (x as { published?: boolean }).published;
      return { ...x, status: x.status ?? (p === undefined ? "live" : p ? "live" : "scheduled") };
    }),
  };
};
export const setMaintenance = (on: boolean, reason: string, until?: string) => owned((t) => own.setMaintenance(t, on, reason, until), "/v1/admin/maintenance", put({ on, until, reason }));
export const setMinVersion = (ios: string, reason: string) => owned((t) => own.setMinVersion(t, ios, reason), "/v1/admin/min-version", put({ ios, reason }));
export const createNotice = (n: { title: string; body: string; publish_at?: string; push?: boolean }, reason: string) =>
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
