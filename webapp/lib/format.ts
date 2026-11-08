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
/** "11월 3일 화요일" */
export const longDate = (iso: string) => parts(iso, { month: "long", day: "numeric", weekday: "long" });
/** "2026-11" in KST */
export const monthKey = (iso: string) => parts(iso, { year: "numeric", month: "2-digit" }).replace(/\. ?/g, "-").replace(/-$/, "");
