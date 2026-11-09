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
