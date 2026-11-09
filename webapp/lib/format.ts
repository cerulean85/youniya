import type { Mood } from "./types";

export const MOODS: { key: Mood; label: string; color: string }[] = [
  { key: "calm", label: "평온", color: "var(--calm)" },
  { key: "sorrow", label: "슬픔", color: "var(--sorrow)" },
  { key: "anger", label: "분노", color: "var(--anger)" },
  { key: "insight", label: "통찰", color: "var(--insight)" },
];
export const moodOf = (m: Mood) => MOODS.find((x) => x.key === m) ?? MOODS[0];

/** The server's MIN_FLOAT_LENGTH: a star floats from 50 characters; keeping has no minimum. */
export const MIN_FLOAT_LENGTH = 50;

const KST = "Asia/Seoul";
const parts = (iso: string, opts: Intl.DateTimeFormatOptions) =>
  new Intl.DateTimeFormat("ko-KR", { timeZone: KST, ...opts }).format(new Date(iso));

/** "11월 3일 · 21:30" */
export function dateTime(iso: string) {
  const d = parts(iso, { month: "long", day: "numeric" });
  const t = parts(iso, { hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
  return `${d} · ${t}`;
}
/** "11월 3일" */
export const monthDay = (iso: string) => parts(iso, { month: "long", day: "numeric" });
/** "11월 3일 화요일" */
export const longDate = (iso: string) => parts(iso, { month: "long", day: "numeric", weekday: "long" });
/** Year, month and day of a moment, in Korean time. */
export function kst(iso: string | Date) {
  const d = typeof iso === "string" ? new Date(iso) : iso;
  const p = Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", { timeZone: KST, year: "numeric", month: "2-digit", day: "2-digit" })
      .formatToParts(d).map((x) => [x.type, x.value]),
  );
  return { y: Number(p.year), m: Number(p.month), d: Number(p.day), month: `${p.year}-${p.month}` };
}
/** "2026-11" → "2026년 11월" */
export const monthLabel = (month: string) => `${month.slice(0, 4)}년 ${Number(month.slice(5))}월`;
/** "2026-11" ± n months */
export function shiftMonth(month: string, n: number) {
  const d = new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5)) - 1 + n, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}
/** "2026-11" → "11월" */
export const monthOnly = (month: string) => `${Number(month.slice(5))}월`;
