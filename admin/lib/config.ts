import "server-only";

/** The API the console talks to. Without one (or with ADMIN_MOCK=1) it runs on mock data. */
export const API_URL = process.env.YOUNIYA_API_URL ?? "";
export const MOCK = !API_URL || process.env.ADMIN_MOCK === "1";
