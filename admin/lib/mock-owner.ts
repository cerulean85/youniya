import "server-only";
import { MockError, operatorOf } from "./mock";
import type { AiUsage, Dashboard, Invites, Ledger, Notices, OperatorRow, Prism, Range } from "./types";

// Mock data for the owner screens (A-02, A-08~A-12, A-14), in memory like lib/mock.ts.
const at = (h: number, m: number) => { const d = new Date(); d.setHours(h, m, 0, 0); return d.toISOString(); };
const daysAgo = (n: number) => new Date(Date.now() - n * 86400000).toISOString();

type State = { prism: Prism; invites: Invites; notices: Notices; operators: OperatorRow[]; log: { at: string; operator: string; action: string; target: string; reason: string }[] };
const g = globalThis as unknown as { __mockOwner?: State };
const st = (): State => (g.__mockOwner ??= {
  prism: {
    versions: [
      { key: "prism-v2", label: "별빛 프리즘 v2", description: "별빛 풀이 문장 다듬기, 근거 인용 짧게", deployed_at: null, stars: null, status: "held" },
      { key: "prism-v1-2026-11", label: "별빛 프리즘 v1", description: "2026년 11월 방식 · 별빛 풀이 추가", deployed_at: "2026-11-09", stars: 18240, status: "active" },
      { key: "prism-v0", label: "(이전)", description: "별빛 풀이 없음", deployed_at: "2026-11-01", stars: 9102, status: "retired" },
    ],
    test: { version: "prism-v2", sample_size: 30, starlight_diff: 41, threshold: 30, rank_flips: 2, depth: 28, clarity: 9, weight: 4, passed: false },
  },
  invites: { enabled: true, items: [
    { id: "i_1", login_id: "review01", memo: "App Store 심사용 · 별 15개, 별자리 2달, 별빛 한 줄", created_at: "2026-11-01", last_login_at: daysAgo(1), enabled: true },
    { id: "i_2", login_id: "qa-ios", memo: "QA · iPhone SE", created_at: "2026-11-03", last_login_at: daysAgo(0.2), enabled: true },
    { id: "i_3", login_id: "demo-web", memo: "웹 데모", created_at: "2026-11-05", last_login_at: null, enabled: false },
  ] },
  notices: {
    maintenance: { on: false }, min_version: { ios: "1.0.2" },
    items: [
      { id: "n_1", title: "11월 별자리는 페가수스자리예요", body: "이번 달 별을 띄우면 페가수스자리의 빈 자리가 채워져요.", audience: "all", starts_at: "2026-11-01", ends_at: "2026-11-30", status: "live" },
      { id: "n_2", title: "11월 12일 새벽 점검 안내", body: "새벽 3시부터 30분 동안 점검해요.", audience: "all", starts_at: "2026-11-10", ends_at: "2026-11-12", status: "scheduled" },
      { id: "n_3", title: "별빛 풀이가 생겼어요", body: "별빛을 받으면 왜 그런 별빛이 나왔는지 풀어 드려요.", audience: "all", starts_at: "2026-11-09", ends_at: "2026-11-16", status: "live" },
    ],
  },
  operators: [
    { id: "op_1", name: "owner", email_masked: "o●●●@youniya.test", role: "owner", totp: true, last_seen_at: new Date().toISOString(), status: "active" },
    { id: "op_2", name: "moderator", email_masked: "m●●●@youniya.test", role: "moderator", totp: true, last_seen_at: daysAgo(1), status: "active" },
  ],
  log: [],
});

const owner = (token: string) => {
  const op = operatorOf(token);
  if (op.role !== "owner") throw new MockError(403, "forbidden_role", "권한이 없어요.");
  return op;
};
const need = (reason: string) => { if (!reason.trim()) throw new MockError(422, "reason_required", "사유를 적어 주세요."); };

export function dashboard(token: string, range: Range): Dashboard {
  owner(token);
  const k = range === "today" ? 1 : range === "week" ? 6.2 : 24;
  return {
    date: new Date().toISOString(),
    stars: { total: Math.round(1284 * k), lit: Math.round(812 * k), unlit: Math.round(472 * k) },
    new_keepers: { count: Math.round(96 * k), delta: 12 },
    reports_pending: { count: 7, overdue: 2 },
    inquiries_new: { count: 4, avg_first_reply_hours: 5 },
    ai_cost_month: { krw: 182400, starlight_share: 71, telescope_share: 29 },
    events: [
      { at: at(10, 51), text: "긴급 · 개인정보 노출 신고 1건 · 바로 숨기고 휴대폰으로 알렸어요", status: "hidden" },
      { at: at(10, 42), text: "별 신고 3건 누적 · 광장에서 자동으로 숨겼어요", status: "hidden" },
      { at: at(10, 15), text: "멤버 원가 경보 · 별지기 #48213 이번 달 ₩2,140", status: "alert" },
      { at: at(9, 58), text: "App Store 환불 알림 · 330코인 회수", status: "done" },
      { at: at(9, 30), text: "별지기 이름 신고 · '운영자공지'", status: "pending" },
      { at: at(8, 2), text: "위기 신호 감지 12건 · 109 안내 표시", status: "ok" },
    ],
    payments_today: { charge_krw: 412500, charge_count: 214, refund_krw: 3300, refund_count: 1, used: { starlight: 6120, telescope: 4060 } },
  };
}

export function ledger(token: string, month: string): Ledger {
  owner(token);
  const k = (id: string, no: string, nickname: string) => ({ id, no, nickname });
  return {
    month,
    summary: { charge_krw: 3982100, charge_count: 1904, refund_krw: 29700, refund_count: 9, usage_share: { starlight: 61, telescope: 39 }, free_used: { starlight: 18240, telescope: 6070 } },
    items: [
      { at: at(10, 21), keeper: k("u_48213", "#48213", "느린고래"), kind: "charge", detail: "코인 330 · App Store", coins: 330, amount_krw: 3300, reference: "2000000812", channel: "app_store" },
      { at: at(10, 2), keeper: k("u_47002", "#47002", "고요한새벽"), kind: "use", detail: "별빛 받기", coins: -5, amount_krw: null, reference: null, channel: null },
      { at: at(9, 58), keeper: k("u_46551", "#46551", "창가고양이"), kind: "refund", detail: "App Store 환불 · 남은 코인만 회수", coins: -330, amount_krw: 3300, reference: "2000000790", channel: "app_store" },
      { at: at(9, 40), keeper: k("u_10001", "#10001", "심사용 계정"), kind: "grant", detail: "운영자 지급 · 심사용", coins: 1000, amount_krw: null, reference: "admin", channel: "admin" },
      { at: at(9, 12), keeper: k("u_48190", "#48190", "바람의끝"), kind: "use", detail: "마음 망원경", coins: -20, amount_krw: null, reference: null, channel: null },
    ],
  };
}

export function ai(token: string, month: string): AiUsage {
  owner(token);
  return {
    month, model: "gemini-3.8-flash", thinking: "low", krw_per_usd: 1500,
    summary: { cost_krw: 182400, change_pct: 8, calls: 24310, failure_rate: 0.4, per_starlight_krw: 7.6, cache_hit: 62, per_telescope_krw: 3.9, member_alerts: 1, member_limit_krw: 2000 },
    features: [
      { key: "starlight", label: "별빛 받기 (별빛 풀이 포함)", calls: 18240, avg_in: 1420, avg_out: 610, cost_krw: 138600 },
      { key: "telescope", label: "마음 망원경", calls: 6070, avg_in: 1980, avg_out: 540, cost_krw: 23700 },
      { key: "crisis", label: "위기 신호 감지", calls: null, avg_in: null, avg_out: null, cost_krw: 0, note: "AI 안 씀" },
    ],
    members: [{ keeper_no: "#48213", cost_krw: 2140, alert: true }, { keeper_no: "#47002", cost_krw: 1320, alert: false }, { keeper_no: "#46551", cost_krw: 980, alert: false }],
  };
}

export const prism = (token: string): Prism => { owner(token); return st().prism; };

export function prismTest(token: string, key: string, reason: string) {
  owner(token); need(reason);
  const p = st().prism;
  if (!p.versions.some((v) => v.key === key && (v.status === "held" || v.status === "draft"))) throw new MockError(409, "not_testable", "시험할 수 있는 버전이 아니에요.");
  p.test = { version: key, sample_size: 30, starlight_diff: 22, threshold: 30, rank_flips: 0, depth: 14, clarity: 6, weight: 2, passed: true };
  return { ok: true };
}

export function prismDeploy(token: string, key: string, reason: string) {
  owner(token); need(reason);
  const p = st().prism;
  if (!p.test || p.test.version !== key || !p.test.passed) throw new MockError(409, "test_not_passed", "시험을 통과해야 배포할 수 있어요.");
  for (const v of p.versions) if (v.status === "active") v.status = "retired";
  const v = p.versions.find((x) => x.key === key)!;
  v.status = "active"; v.deployed_at = new Date().toISOString().slice(0, 10); v.stars = 0;
  return { ok: true };
}

export const invites = (token: string): Invites => { owner(token); return st().invites; };
export function invitesEnabled(token: string, on: boolean, reason: string) { owner(token); need(reason); st().invites.enabled = on; return { ok: true }; }
export function createInvite(token: string, loginId: string, memo: string, reason: string) {
  owner(token); need(reason);
  if (!/^[a-z0-9-]{4,20}$/.test(loginId)) throw new MockError(422, "invalid", "아이디는 영문 소문자·숫자·- 4~20자예요.");
  if (st().invites.items.some((i) => i.login_id === loginId)) throw new MockError(409, "taken", "이미 있는 아이디예요.");
  const password = Array.from(crypto.getRandomValues(new Uint8Array(12)), (b) => "abcdefghjkmnpqrstuvwxyz23456789"[b % 31]).join("");
  st().invites.items.push({ id: crypto.randomUUID(), login_id: loginId, memo, created_at: new Date().toISOString().slice(0, 10), last_login_at: null, enabled: true });
  return { password };
}
export function setInvite(token: string, id: string, on: boolean, reason: string) {
  owner(token); need(reason);
  const i = st().invites.items.find((x) => x.id === id);
  if (!i) throw new MockError(404, "not_found", "찾지 못했어요.");
  i.enabled = on; return { ok: true };
}
export function reseed(token: string, id: string, reason: string) { owner(token); need(reason); if (!st().invites.items.some((x) => x.id === id)) throw new MockError(404, "not_found", "찾지 못했어요."); return { ok: true }; }

export const notices = (token: string): Notices => { owner(token); return st().notices; };
export function setMaintenance(token: string, on: boolean, reason: string) { owner(token); need(reason); st().notices.maintenance.on = on; return { ok: true }; }
export function setMinVersion(token: string, ios: string, reason: string) {
  owner(token); need(reason);
  if (!/^\d+\.\d+\.\d+$/.test(ios)) throw new MockError(422, "invalid", "1.0.3 같은 모양으로 적어 주세요.");
  st().notices.min_version.ios = ios; return { ok: true };
}
export function createNotice(token: string, n: { title: string; body: string; audience: "all" | "ios" | "web"; starts_at: string; ends_at: string }, reason: string) {
  owner(token); need(reason);
  if (!n.title.trim() || !n.starts_at || !n.ends_at || n.ends_at < n.starts_at) throw new MockError(422, "invalid", "제목과 기간을 확인해 주세요.");
  const today = new Date().toISOString().slice(0, 10);
  st().notices.items.unshift({ id: crypto.randomUUID(), ...n, status: n.starts_at > today ? "scheduled" : n.ends_at < today ? "ended" : "live" });
  return { ok: true };
}

export const operators = (token: string): OperatorRow[] => { owner(token); return st().operators; };
export function inviteOperator(token: string, email: string, role: "owner" | "moderator", reason: string) {
  owner(token); need(reason);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new MockError(422, "invalid", "이메일을 확인해 주세요.");
  st().operators.push({ id: crypto.randomUUID(), name: email.split("@")[0], email_masked: `${email[0]}●●●@${email.split("@")[1]}`, role, totp: false, last_seen_at: null, status: "invited" });
  return { ok: true };
}
export function updateOperator(token: string, id: string, patch: { role?: "owner" | "moderator"; status?: "active" | "disabled" }, reason: string) {
  const me = owner(token); need(reason);
  const o = st().operators.find((x) => x.id === id);
  if (!o) throw new MockError(404, "not_found", "찾지 못했어요.");
  if (o.id === me.id) throw new MockError(409, "self", "자기 자신의 권한은 바꿀 수 없어요.");
  if (o.role === "owner" && (patch.role === "moderator" || patch.status === "disabled") && st().operators.filter((x) => x.role === "owner" && x.status === "active").length < 2)
    throw new MockError(409, "last_owner", "운영자(owner)는 한 명 이상 남아 있어야 해요.");
  Object.assign(o, patch); return { ok: true };
}
