const KST = "Asia/Seoul";

/** "2시간", "26시간", "1일" since then. */
export function elapsed(iso: string, now = Date.now()) {
  const m = Math.max(0, Math.round((now - new Date(iso).getTime()) / 60000));
  if (m < 60) return `${m}분`;
  if (m < 48 * 60) return `${Math.floor(m / 60)}시간`;
  return `${Math.floor(m / 1440)}일`;
}

export const time = (iso: string) => new Intl.DateTimeFormat("ko-KR", { timeZone: KST, hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date(iso));
export const dateTime = (iso: string) => new Intl.DateTimeFormat("ko-KR", { timeZone: KST, month: "long", day: "numeric", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date(iso));

export const won = (n: number) => `₩${n.toLocaleString("ko-KR")}`;
export const num = (n: number) => n.toLocaleString("ko-KR");
export const thisMonth = () => new Intl.DateTimeFormat("en-CA", { timeZone: KST, year: "numeric", month: "2-digit" }).format(new Date()).slice(0, 7);
export const monthLabel = (m: string) => `${Number(m.slice(5))}월`;
export const longToday = () => new Intl.DateTimeFormat("ko-KR", { timeZone: KST, year: "numeric", month: "long", day: "numeric", weekday: "long" }).format(new Date());
