import "server-only";
import { MockError, operatorOf } from "./mock";
import type { AuditEntry, InquiryDetail, InquiryStatus, KeeperAction, KeeperDetail, KeeperOrder, KeeperRow } from "./types";
import { MODERATOR_KEEPER_ACTIONS } from "./types";

// Mock 별지기 and 문의 for A-05~A-07 (in memory, like lib/mock.ts).
const g = globalThis as unknown as { __mockMore?: { keepers: Map<string, KeeperDetail>; inquiries: Map<string, InquiryDetail> } };
const days = (n: number) => new Date(Date.now() - n * 86400000).toISOString();
const hours = (n: number) => new Date(Date.now() - n * 3600000).toISOString();
const later = (n: number) => new Date(Date.now() + n * 86400000).toISOString();

function seed() {
  const keepers = new Map<string, KeeperDetail>();
  const k = (id: string, no: string, nickname: string | null, joined: number, provider: string, lit: number, unlit: number, shared: number, reports: number, coins: number, restrictedDays: number | null, marketing: boolean, history: AuditEntry[] = []) =>
    keepers.set(id, {
      id, no, nickname, joined_at: days(joined), provider, stars: lit + unlit, shared, reports, coins,
      status: restrictedDays ? "restricted" : "active", restricted_until: restrictedDays ? later(restrictedDays) : null,
      last_seen_at: hours(Math.round(joined / 3)), star_counts: { lit, unlit },
      consents: { terms_at: days(joined), terms_version: "v2026-11-01", sensitive_at: days(joined), marketing: { opt_in: marketing, at: marketing ? days(joined) : null } },
      nickname_next_change: later(21), deletion_requested_at: null, history,
    });
  k("u_48213", "#48213", "느린고래", 38, "apple", 40, 8, 6, 0, 120, null, true);
  k("u_48190", "#48190", "바람의끝", 39, "google", 15, 7, 9, 3, 0, 7, false, [
    { at: days(0), operator: "owner@youniya.test", action: "restrict_7d", target: "star:120394", reason: "광장 이용 7일 제한 · 괴롭힘 신고 3건" },
    { at: days(7), operator: "owner@youniya.test", action: "take_down", target: "star_line:88001", reason: "별빛 한 줄 1개 내리기 · 광고" },
  ]);
  k("u_47002", "#47002", "고요한새벽", 42, "apple", 60, 11, 14, 0, 540, null, true);
  k("u_10001", "#10001", "심사용 계정", 8, "invite", 12, 3, 3, 0, 1000, null, false);
  k("u_46551", "#46551", "창가고양이", 50, "google", 7, 2, 2, 1, 30, null, false);
  k("u_7781", "#51120", "운영자공지", 1, "apple", 1, 0, 0, 2, 0, 30, false);
  k("u_52001", "#52001", null, 0, "google", 0, 1, 0, 0, 0, null, false);
  keepers.get("u_52001")!.deletion_requested_at = hours(5);

  const inquiries = new Map<string, InquiryDetail>();
  const q = (id: string, kind: string, title: string, h: number, status: InquiryStatus, body: string, email: string, keeper: InquiryDetail["keeper"], purchase: InquiryDetail["purchase"] = null) =>
    inquiries.set(id, { id, kind, title, created_at: hours(h), status, body, email_masked: email, keeper, app: { platform: "iOS", version: "1.0.3", device: "iPhone 15" }, purchase, replies: [] });
  q("q_5", "payment", "코인이 안 들어왔어요", 1, "new", "330코인을 샀는데 잔액이 그대로예요. 결제는 됐다고 나와요.", "s●●●@gmail.com", { id: "u_48213", no: "#48213", nickname: "느린고래" }, { transaction_id: "2000000812", status: "확인 중" });
  q("q_4", "bug", "별빛 풀이가 안 열려요", 3, "new", "별 상세에서 별빛 풀이 보기를 눌러도 아무 반응이 없어요.", "k●●●@naver.com", { id: "u_47002", no: "#47002", nickname: "고요한새벽" });
  q("q_3", "account", "별지기 이름을 바꾸고 싶어요", 26, "new", "실수로 이름을 잘못 정했어요. 30일을 기다려야 하나요?", "m●●●@icloud.com", { id: "u_46551", no: "#46551", nickname: "창가고양이" });
  q("q_2", "idea", "달력에서 바로 쓰고 싶어요", 30, "new", "기록 달력에서 날짜를 눌러 그날 글을 바로 쓰면 좋겠어요.", "j●●●@gmail.com", null);
  q("q_1", "payment", "환불 문의", 52, "answered", "실수로 두 번 결제했어요. 하나는 환불할 수 있을까요?", "p●●●@gmail.com", { id: "u_48190", no: "#48190", nickname: "바람의끝" }, { transaction_id: "2000000777", status: "환불 안내" });
  inquiries.get("q_1")!.replies.push({ at: hours(40), operator: "owner@youniya.test", body: "App Store의 문제 신고하기에서 환불을 요청해 주세요. 쓰지 않은 코인이라면 환불돼요." });
  return { keepers, inquiries };
}
const st = () => (g.__mockMore ??= seed());

const row = (k: KeeperDetail): KeeperRow => ({ id: k.id, no: k.no, nickname: k.nickname, joined_at: k.joined_at, provider: k.provider, stars: k.stars, shared: k.shared, reports: k.reports, coins: k.coins, status: k.status, restricted_until: k.restricted_until });

export function listKeepers(token: string, q: string, filter: string): KeeperRow[] {
  operatorOf(token);
  const term = q.trim().replace(/^#/, "");
  return [...st().keepers.values()].filter((k) =>
    (!term || (k.nickname ?? "").includes(term) || k.no.includes(term)) &&
    (filter === "restricted" ? k.status === "restricted" : filter === "reported" ? k.reports > 0 : filter === "invite" ? k.provider === "invite" : true),
  ).map(row);
}

export function keepersCsv(token: string) {
  if (operatorOf(token).role !== "owner") throw new MockError(403, "forbidden_role", "권한이 없어요.");
  const head = "번호,별지기,가입,로그인,별,나눈 별,신고 받음,코인,상태";
  return [head, ...[...st().keepers.values()].map((k) => [k.no, k.nickname ?? "", k.joined_at.slice(0, 10), k.provider, k.stars, k.shared, k.reports, k.coins, k.status].join(","))].join("\n");
}

export function getKeeper(token: string, id: string): KeeperDetail {
  operatorOf(token);
  const k = st().keepers.get(id);
  if (!k) throw new MockError(404, "not_found", "별지기를 찾지 못했어요.");
  return k;
}

export function keeperAction(token: string, id: string, action: KeeperAction, reason: string, amount?: number, daysN?: number) {
  const op = operatorOf(token), k = getKeeper(token, id);
  if (op.role !== "owner" && !MODERATOR_KEEPER_ACTIONS.includes(action)) throw new MockError(403, "forbidden_role", "권한이 없어요.");
  if (!reason.trim()) throw new MockError(422, "reason_required", "사유를 적어 주세요.");
  if (action === "lift_restriction") { k.status = "active"; k.restricted_until = null; }
  if (action === "extend_restriction") { k.status = "restricted"; k.restricted_until = new Date((k.restricted_until ? new Date(k.restricted_until).getTime() : Date.now()) + (daysN ?? 7) * 86400000).toISOString(); }
  if (action === "grant_coins") {
    if (!amount || amount < 1 || amount > 10000) throw new MockError(422, "invalid_amount", "1~10,000 코인 사이로 적어 주세요.");
    k.coins += amount;
  }
  if (action === "revoke_coins") {
    if (!amount || amount < 1 || amount > 10000) throw new MockError(422, "invalid_amount", "1~10,000 코인 사이로 적어 주세요.");
    if (amount > k.coins) throw new MockError(409, "insufficient_balance", `남은 코인(${k.coins})보다 많이 회수할 수 없어요.`);
    k.coins -= amount;
  }
  if (action === "process_deletion" && !k.deletion_requested_at) throw new MockError(409, "no_request", "계정 삭제 요청이 없어요.");
  const extra = action === "grant_coins" || action === "revoke_coins" ? ` · ${amount}코인` : action === "extend_restriction" ? ` · ${daysN ?? 7}일` : "";
  k.history.unshift({ at: new Date().toISOString(), operator: op.email, action, target: `keeper:${k.no}`, reason: `${reason}${extra}` });
  if (action === "process_deletion") st().keepers.delete(id);
  return { ok: true };
}

export function listInquiries(token: string, status: InquiryStatus) {
  operatorOf(token);
  const all = [...st().inquiries.values()].sort((a, b) => b.created_at.localeCompare(a.created_at));
  return {
    items: all.filter((x) => x.status === status).map(({ id, kind, title, created_at, status: s }) => ({ id, kind, title, created_at, status: s })),
    counts: { new: all.filter((x) => x.status === "new").length, answered: all.filter((x) => x.status === "answered").length },
  };
}

export function getInquiry(token: string, id: string): InquiryDetail {
  operatorOf(token);
  const x = st().inquiries.get(id);
  if (!x) throw new MockError(404, "not_found", "문의를 찾지 못했어요.");
  return x;
}

export function reply(token: string, id: string, body: string) {
  const op = operatorOf(token), x = getInquiry(token, id);
  if (!body.trim()) throw new MockError(422, "empty", "답장을 적어 주세요.");
  x.replies.push({ at: new Date().toISOString(), operator: op.email, body });
  x.status = "answered";
  return { ok: true };
}

// Toss orders for 운영자 환불: 느린고래 has one refundable, one past 7 days and one already refunded.
const orders = (globalThis as unknown as { __mockOrders?: Map<string, KeeperOrder & { keeper: string }> });
function orderStore() {
  if (!orders.__mockOrders) {
    const o = new Map<string, KeeperOrder & { keeper: string }>();
    const add = (id: string, keeper: string, ago: number, coins: number, amount: number, status: KeeperOrder["status"]) =>
      o.set(id, { id, keeper, created_at: days(ago), package_id: `coins_${coins}`, coins, amount, status, canceled_at: status === "canceled" ? days(ago - 1) : null, refundable: false, refund_block: null });
    add("ord_3", "u_48213", 2, 50, 4900, "done");
    add("ord_2", "u_48213", 12, 120, 9900, "done");
    add("ord_1", "u_48213", 20, 50, 4900, "canceled");
    add("ord_4", "u_47002", 1, 300, 22000, "done");
    orders.__mockOrders = o;
  }
  return orders.__mockOrders;
}
function view(o: KeeperOrder & { keeper: string }, coins: number): KeeperOrder {
  const block = o.status !== "done" ? (o.status === "canceled" ? null : "not_done")
    : Date.now() - new Date(o.created_at).getTime() > 7 * 86400000 ? "window_passed" : coins < o.coins ? "coins_spent" : null;
  const { keeper: _k, ...rest } = o; void _k;
  return { ...rest, refundable: o.status === "done" && !block, refund_block: block };
}
export function keeperOrders(token: string, id: string): KeeperOrder[] {
  const k = getKeeper(token, id);
  return [...orderStore().values()].filter((o) => o.keeper === id).sort((a, b) => b.created_at.localeCompare(a.created_at)).map((o) => view(o, k.coins));
}
export function refundOrder(token: string, orderId: string, reason: string, force: boolean) {
  const op = operatorOf(token);
  if (op.role !== "owner") throw new MockError(403, "forbidden_role", "권한이 없어요.");
  if (!reason.trim()) throw new MockError(422, "reason_required", "사유를 적어 주세요.");
  const o = orderStore().get(orderId);
  if (!o) throw new MockError(404, "not_found", "주문을 찾지 못했어요.");
  const k = getKeeper(token, o.keeper);
  const v = view(o, k.coins);
  if (o.status !== "done") throw new MockError(409, "order_not_done", "환불할 수 있는 결제가 아니에요.");
  if (!force && v.refund_block === "window_passed") throw new MockError(409, "refund_window_passed", "결제한 지 7일이 지나 환불할 수 없어요.");
  if (!force && v.refund_block === "coins_spent") throw new MockError(409, "coins_spent", "이 결제로 받은 코인을 이미 써서 환불할 수 없어요.");
  const taken = Math.min(o.coins, k.coins);
  k.coins -= taken;
  o.status = "canceled"; o.canceled_at = new Date().toISOString();
  k.history.unshift({ at: o.canceled_at, operator: op.email, action: "refund", target: `order:${o.id}`, reason: `${reason} · ${o.amount.toLocaleString("ko-KR")}원 · 코인 ${taken}개 회수${force ? " · 예외" : ""}` });
  return { coins_taken: taken };
}
