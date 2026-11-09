// Shapes from the API Dev Session's proposal for /v1/admin (2026-11-09; built in its step 7).
export type Role = "owner" | "moderator";
export type Operator = { id: string; email: string; role: Role };

export type ReportKind = "star" | "star_line" | "line" | "nickname";
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
  keeper: { id: string; nickname: string };
  reports: { reporter_no: string; reason: string; note?: string | null; at: string }[];
  actions: AuditEntry[];
};

export const KIND_LABEL: Record<ReportKind, string> = { star: "별", star_line: "별빛 한 줄", line: "별빛 한 줄", nickname: "별지기 이름" };
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
