import { api } from "@/lib/api";
import styles from "./Sidebar.module.css";

/** A gold dot beside 알림 while something is unread. Quiet on servers without the 알림함 API. */
export async function UnreadDot() {
  const r = await api<{ unread: number }>("/v1/me/notifications?limit=1").catch(() => null);
  if (!r?.unread) return null;
  return <span className={styles.unread} role="status" aria-label={`안 읽은 알림 ${r.unread}개`} />;
}
