// Shapes from the API Dev Session's proposal for /v1/admin (2026-11-09; built in its step 7).
export type Role = "owner" | "moderator";
export type Operator = { id: string; email: string; role: Role };

/** line = a line left on a nebula (older builds); star_line = one left on a star; nickname: target_id is the keeper's id. */
export type ReportKind = "star" | "nebula" | "star_line" | "line" | "nickname";
export type ReportStatus = "pending" | "hidden" | "done";
export type ReportItem = {
  id: string; kind: ReportKind; target_id: string;
  /** Only what the plaza shows. */
  preview: string;
  reasons: Record<string, number>; reports: number; first_reported_at: string; status: ReportStatus;
};
export type ActionKind = "restore" | "take_down" | "request_rename" | "restrict_7d" | "restrict_30d" | "note";
export type AuditEntry = { at: string; operator: string; action: ActionKind | string; target: string; reason: string };
export type ReportDetail = {
  kind: ReportKind; target_id: string; status: ReportStatus; auto_hidden: boolean;
  /** 공개된 것만: 대표 문장 · 공개 본문 · 한 줄 · 이름. */
  content: { quote?: string; body_masked?: string; line?: string; nickname?: string; shared_at?: string };
  keeper: { id: string; no?: string; nickname: string | null };
  reports: { reporter_no: string; reason: string; note?: string | null; at: string }[];
  actions: AuditEntry[];
};

export const KIND_LABEL: Record<ReportKind, string> = { star: "별", nebula: "성운", star_line: "별빛 한 줄", line: "성운 별빛 한 줄", nickname: "별지기 이름" };
export const STATUS_LABEL: Record<ReportStatus, string> = { pending: "대기", hidden: "숨김", done: "처리 완료" };
export const REASON_LABEL: Record<string, string> = {
  hurtful: "상처 주는 말", personal_info: "개인정보", self_harm: "자해", harassment: "괴롭힘", hate: "혐오·비하",
  impersonation: "사칭", advertising: "광고", nickname: "부적절한 이름", spam: "스팸", other: "기타",
};
export const ACTION_LABEL: Record<string, string> = {
  restore: "숨김 풀기 · 문제 없음", take_down: "광장에서 내리기", request_rename: "별지기 이름 바꾸기 요청",
  restrict_7d: "광장 이용 7일 제한", restrict_30d: "광장 이용 30일 제한", note: "메모",
};
/** 18.3: personal_info and self_harm hide at the first report; the rest at three. */
export const INSTANT_REASONS = ["personal_info", "self_harm"];

// 별지기 (A-05, A-06) and 문의 (A-07): the web console's proposal, sent to the API Dev Session (2026-11-09).
export type KeeperStatus = "active" | "restricted";
export type KeeperRow = {
  id: string; no: string; nickname: string | null; joined_at: string; provider: "apple" | "google" | "invite" | string;
  stars: number; shared: number; reports: number; coins: number; status: KeeperStatus; restricted_until: string | null;
};
export type KeeperDetail = KeeperRow & {
  last_seen_at: string | null;
  star_counts: { lit: number; unlit: number };
  consents: { terms_at: string | null; terms_version: string | null; sensitive_at: string | null; marketing: { opt_in: boolean; at: string | null } };
  nickname_next_change: string | null;
  deletion_requested_at: string | null;
  history: AuditEntry[];
};
export type KeeperAction = "lift_restriction" | "extend_restriction" | "request_rename" | "grant_coins" | "process_deletion";
export const KEEPER_ACTION_LABEL: Record<KeeperAction, string> = {
  lift_restriction: "제한 풀기", extend_restriction: "제한 늘리기", request_rename: "별지기 이름 바꾸기 요청",
  grant_coins: "코인 지급", process_deletion: "계정 삭제 요청 처리",
};
/** Moderators may restrict or lift plaza use and ask for a new name; coins and deletion are owners'. */
export const MODERATOR_KEEPER_ACTIONS: KeeperAction[] = ["lift_restriction", "extend_restriction", "request_rename"];
export const PROVIDER_LABEL: Record<string, string> = { apple: "Apple", google: "Google", invite: "초대", dev: "테스트" };

export type InquiryStatus = "new" | "answered";
export type InquiryRow = { id: string; kind: string; title: string; created_at: string; status: InquiryStatus };
export type InquiryDetail = InquiryRow & {
  body: string; email_masked: string;
  keeper: { id: string; no: string; nickname: string | null } | null;
  app: { platform: string; version: string; device: string } | null;
  purchase: { transaction_id: string; status: string } | null;
  /** `sent`: whether the email went out (Resend). */
  replies: { at: string; operator: string; body: string; sent?: boolean }[];
};
export const INQUIRY_KIND_LABEL: Record<string, string> = { payment: "결제", bug: "오류", account: "계정", idea: "제안", other: "기타" };

// A-02, A-08~A-12, A-14 (owners only): the web console's proposal (2026-11-09).
export type Range = "today" | "week" | "month";
export type Dashboard = {
  date: string;
  stars: { total: number; lit: number; unlit: number };
  new_keepers: { count: number; delta: number };
  reports_pending: { count: number; overdue: number };
  inquiries_new: { count: number; avg_first_reply_hours: number | null };
  ai_cost_month: { krw: number; starlight_share: number; telescope_share: number };
  events: { at: string; text: string; status: "hidden" | "alert" | "done" | "pending" | "ok" }[];
  payments_today: { charge_krw: number; charge_count: number; refund_krw: number; refund_count: number; used: { starlight: number; telescope: number } };
};
export type LedgerKind = "charge" | "use" | "refund" | "grant";
export type Ledger = {
  month: string;
  summary: { charge_krw: number; charge_count: number; refund_krw: number; refund_count: number; usage_share: { starlight: number; telescope: number }; free_used: { starlight: number; telescope: number } };
  items: { at: string; keeper: { id: string; no: string; nickname: string | null }; kind: LedgerKind; detail: string; coins: number; amount_krw: number | null; reference: string | null; channel: "app_store" | "toss" | "admin" | null }[];
};
export type AiUsage = {
  month: string; model: string; thinking: string; krw_per_usd: number;
  summary: { cost_krw: number; change_pct: number; calls: number; failure_rate: number; per_starlight_krw: number; cache_hit: number; per_telescope_krw: number; member_alerts: number; member_limit_krw: number };
  /** Per feature this month; the failure rate is failures / attempts (ai_usage; the reading call is prism_reading). */
  features: { key: string; label: string; calls: number | null; attempts?: number; failures?: number; avg_in: number | null; avg_out: number | null; cost_krw: number; note?: string }[];
  members: { keeper_no: string; cost_krw: number; alert: boolean }[];
};
export type PrismStatus = "draft" | "held" | "active" | "retired";
export type Prism = {
  versions: { key: string; label: string; description: string; deployed_at: string | null; stars: number | null; status: PrismStatus }[];
  test: { version: string; sample_size: number; starlight_diff: number; threshold: number; rank_flips: number; depth: number; clarity: number; weight: number; passed: boolean } | null;
};
export type Invites = { enabled: boolean; items: { id: string; login_id: string; memo: string; created_at: string; last_login_at: string | null; enabled: boolean }[] };
export type Notices = {
  maintenance: { on: boolean };
  min_version: { ios: string };
  items: { id: string; title: string; body: string; audience: "all" | "ios" | "web"; starts_at: string; ends_at: string; status: "scheduled" | "live" | "ended" }[];
};
export type OperatorRow = { id: string; name: string; email_masked: string; role: Role; totp: boolean; last_seen_at: string | null; status: "active" | "invited" | "disabled" };
