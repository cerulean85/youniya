import "server-only";
import type { ActionKind, AuditEntry, Operator, ReportDetail, ReportItem, ReportKind, ReportStatus } from "./types";
import { INSTANT_REASONS } from "./types";

// Mock data for the console until the API Dev Session ships /v1/admin (its step 7). Kept in memory, so it
// resets when the dev server restarts. Sign-in values are in README.md.
const OPERATORS: (Operator & { password: string })[] = [
  { id: "op_1", email: "owner@youniya.test", role: "owner", password: "mock-owner-pass" },
  { id: "op_2", email: "moderator@youniya.test", role: "moderator", password: "mock-mod-pass" },
];
const TOTP = "123456";

const g = globalThis as unknown as { __mock?: State };
type State = {
  fails: Map<string, { n: number; until?: number }>;
  challenges: Map<string, string>;
  tokens: Map<string, Operator>;
  reports: Map<string, ReportDetail & { first_reported_at: string }>;
};

const ago = (min: number) => new Date(Date.now() - min * 60000).toISOString();

function seed(): State {
  const reports = new Map<string, ReportDetail & { first_reported_at: string }>();
  const add = (kind: ReportKind, id: string, status: ReportStatus, auto: boolean, content: ReportDetail["content"], nick: string, rs: [string, string, number, string?][]) =>
    reports.set(`${kind}:${id}`, {
      kind, target_id: id, status, auto_hidden: auto, content, keeper: { id: `u_${id}`, nickname: nick },
      reports: rs.map(([no, reason, min, note]) => ({ reporter_no: no, reason, at: ago(min), note: note ?? null })),
      actions: [], first_reported_at: ago(Math.max(...rs.map((r) => r[2]))),
    });
  add("star", "120394", "hidden", true, { quote: "그만 좀 하라고 했잖아. 왜 내 말은 늘 무시돼?", body_masked: "오늘 회의에서 또 내 의견이 묻혔다. 그만 좀 하라고 했잖아… 팀장님은 늘 ●●● 편만 든다.", shared_at: ago(300) },
    "바람의끝", [["#51022", "harassment", 120, "특정인을 겨냥한 말 같아요"], ["#50311", "harassment", 95], ["#49877", "hate", 40]]);
  add("star_line", "88213", "pending", false, { line: "너도 똑같네" }, "새벽두시", [["#40117", "hate", 300]]);
  add("nickname", "u_7781", "pending", false, { nickname: "운영자공지" }, "운영자공지", [["#33002", "impersonation", 1560], ["#33910", "impersonation", 900]]);
  add("star", "120588", "hidden", true, { quote: "연락 주세요 010-●●●●-●●●●", body_masked: "외로운 밤이에요. 누구라도 연락 주세요 010-●●●●-●●●●", shared_at: ago(50) },
    "밤고양이", [["#47120", "personal_info", 30]]);
  add("star", "119870", "done", false, { quote: "오늘도 버텼다", body_masked: "오늘도 버텼다. 내일은 조금 덜 힘들었으면.", shared_at: ago(2000) }, "느린고래", [["#21007", "other", 1440]]);
  add("star_line", "88190", "hidden", true, { line: "광고 링크 눌러 보세요" }, "별사냥꾼", [["#11", "advertising", 40], ["#12", "advertising", 38], ["#13", "advertising", 30], ["#14", "spam", 20]]);
  add("star", "120701", "pending", false, { quote: "다 사라졌으면 좋겠다", body_masked: "가끔은 다 사라졌으면 좋겠다는 생각이 들어요.", shared_at: ago(15) }, "회색구름", [["#60231", "other", 10]]);
  reports.get("star:119870")!.actions.push({ at: ago(1300), operator: "owner@youniya.test", action: "restore", target: "star:119870", reason: "운영 정책에 어긋나지 않음" });
  return { fails: new Map(), challenges: new Map(), tokens: new Map(), reports };
}
export const state = () => (g.__mock ??= seed());

export class MockError extends Error {
  constructor(public status: number, public code: string, message: string, public data: Record<string, unknown> = {}) { super(message); }
}

export function login(email: string, password: string) {
  const s = state(), f = s.fails.get(email) ?? { n: 0 };
  if (f.until && f.until > Date.now()) throw new MockError(423, "locked", "로그인 시도가 많아 잠겼어요.", { until: new Date(f.until).toISOString() });
  const op = OPERATORS.find((o) => o.email === email && o.password === password);
  if (!op) {
    f.n += 1;
    if (f.n >= 5) { f.until = Date.now() + 15 * 60000; f.n = 0; }
    s.fails.set(email, f);
    throw new MockError(401, "invalid", "이메일이나 비밀번호가 맞지 않아요.");
  }
  const challenge = crypto.randomUUID();
  s.challenges.set(challenge, op.id);
  return { challenge };
}

export function totp(challenge: string, code: string) {
  const s = state(), id = s.challenges.get(challenge);
  const op = OPERATORS.find((o) => o.id === id);
  if (!op) throw new MockError(401, "expired", "처음부터 다시 로그인해 주세요.");
  if (code !== TOTP) throw new MockError(401, "invalid_code", "인증 코드가 맞지 않아요.");
  s.challenges.delete(challenge);
  const token = crypto.randomUUID(), operator = { id: op.id, email: op.email, role: op.role };
  s.tokens.set(token, operator);
  return { token, expires_at: new Date(Date.now() + 8 * 3600000).toISOString(), operator };
}

export function logout(token: string) { state().tokens.delete(token); }

export function operatorOf(token: string) {
  const op = state().tokens.get(token);
  if (!op) throw new MockError(401, "unauthorized", "다시 로그인해 주세요.");
  return op;
}

export function listReports(token: string, status?: ReportStatus): { items: ReportItem[]; counts: Record<ReportStatus, number> } {
  operatorOf(token);
  const all = [...state().reports.values()].map((r): ReportItem => {
    const reasons: Record<string, number> = {};
    for (const x of r.reports) reasons[x.reason] = (reasons[x.reason] ?? 0) + 1;
    const preview = r.kind === "nickname" ? `별지기 이름 '${r.content.nickname}'` : r.kind === "star" ? `“${r.content.quote}” · 별 #${r.target_id}` : `별빛 한 줄 “${r.content.line}”`;
    return { id: `${r.kind}:${r.target_id}`, kind: r.kind, target_id: r.target_id, preview, reasons, reports: r.reports.length, first_reported_at: r.first_reported_at, status: r.status };
  }).sort((a, b) => a.first_reported_at.localeCompare(b.first_reported_at));
  const counts = { pending: 0, hidden: 0, done: 0 };
  for (const r of all) counts[r.status] += 1;
  return { items: status ? all.filter((r) => r.status === status) : all, counts };
}

export function getReport(token: string, kind: ReportKind, id: string): ReportDetail {
  operatorOf(token);
  const r = state().reports.get(`${kind}:${id}`);
  if (!r) throw new MockError(404, "not_found", "신고를 찾지 못했어요.");
  return r;
}

export function act(token: string, kind: ReportKind, id: string, action: ActionKind, reason: string, note?: string) {
  const op = operatorOf(token);
  const r = getReport(token, kind, id);
  if (!reason.trim()) throw new MockError(422, "reason_required", "사유를 적어 주세요.");
  if (action === "request_rename" && kind !== "nickname" && !r.keeper) throw new MockError(422, "invalid", "바꿀 이름이 없어요.");
  const entry: AuditEntry = { at: new Date().toISOString(), operator: op.email, action, target: `${kind}:${id}`, reason: note ? `${reason} · ${note}` : reason };
  r.actions.unshift(entry);
  if (action === "restore") { r.status = "done"; r.auto_hidden = false; }
  else if (action !== "note") r.status = "done";
  return { status: r.status, action_id: crypto.randomUUID() };
}

export function audit(token: string): AuditEntry[] {
  operatorOf(token);
  return [...state().reports.values()].flatMap((r) => r.actions).sort((a, b) => b.at.localeCompare(a.at));
}

export const autoHideRule = (reasons: string[]) => reasons.some((x) => INSTANT_REASONS.includes(x)) ? 1 : 3;
