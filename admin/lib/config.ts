import "server-only";

/** The API the console talks to. Without one (or with ADMIN_MOCK=1) everything runs on mock data. */
export const API_URL = process.env.YOUNIYA_API_URL ?? "";
export const MOCK = !API_URL || process.env.ADMIN_MOCK === "1";

/**
 * Which parts already speak to the real /v1/admin, as the API Dev Session ships them (step 7):
 * ADMIN_REAL=auth,operators,audit,reports,keepers,inquiries (or "all"). The rest keeps its mock data, under the real session.
 */
const REAL = new Set((process.env.ADMIN_REAL ?? "all").split(",").map((s) => s.trim()).filter(Boolean));
export type Part = "auth" | "operators" | "audit" | "reports" | "keepers" | "inquiries" | "owner" | "payments";
/** Parts asked for after "all" was set in production: they need their own name in ADMIN_REAL until the API ships them
 *  (payments: 운영자 환불 · 코인 회수, requested 2026-11-10). */
const LATER: Part[] = ["payments"];
export const live = (part: Part) => !MOCK && (REAL.has(part) || (REAL.has("all") && !LATER.includes(part)));

/** Whether a screen may show: with a real API, parts that aren't live yet show "서버 연결 대기", never mock data. */
export const ready = (part: Part) => MOCK || live(part);
