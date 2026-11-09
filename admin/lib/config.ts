import "server-only";

/** The API the console talks to. Without one (or with ADMIN_MOCK=1) everything runs on mock data. */
export const API_URL = process.env.YOUNIYA_API_URL ?? "";
export const MOCK = !API_URL || process.env.ADMIN_MOCK === "1";

/**
 * Which parts already speak to the real /v1/admin, as the API Dev Session ships them (step 7):
 * ADMIN_REAL=auth,operators,audit,reports,keepers,inquiries (or "all"). The rest keeps its mock data, under the real session.
 */
const REAL = new Set((process.env.ADMIN_REAL ?? "all").split(",").map((s) => s.trim()).filter(Boolean));
export type Part = "auth" | "operators" | "audit" | "reports" | "keepers" | "inquiries" | "owner";
export const live = (part: Part) => !MOCK && (REAL.has("all") || REAL.has(part));
