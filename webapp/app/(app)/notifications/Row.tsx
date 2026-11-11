import Link from "next/link";
import { kindOf, targetHref } from "@/lib/notifications";
import type { AppNotification } from "@/lib/types";
import styles from "./notifications.module.css";

/** One card of W-58: dot, kind and time, title, body, and the link that opens its screen (marking it read). */
export function NotificationRow({ n, ago }: { n: AppNotification; ago: string }) {
  const k = kindOf(n), href = targetHref(n.target);
  // 신고 처리 결과 has no link (W-58).
  const go = href && k.action ? `/notifications/go?id=${encodeURIComponent(n.id)}&to=${encodeURIComponent(href)}` : null;
  const body = (
    <>
      <span className={styles.dot} style={{ ["--c" as string]: k.color }} aria-hidden="true" />
      <span className={styles.text}>
        <span className={styles.meta}><span style={{ color: k.color }}>{k.label}</span><span className="faint">{ago}</span></span>
        <span className={styles.title}>{n.title}</span>
        <span className={styles.body}>{n.body}</span>
      </span>
      {go && <span className={styles.action}>{k.action} ›</span>}
    </>
  );
  return (
    <li className={styles.item} data-unread={!n.read || undefined}>
      {go ? <Link href={go} prefetch={false} aria-label={`${n.title} · ${k.action}`}>{body}</Link> : <div>{body}</div>}
    </li>
  );
}

/** "방금" / "12분 전" / "1시간 전" / "2일 전". */
export function ago(iso: string, now: number) {
  const m = Math.max(0, Math.round((now - new Date(iso).getTime()) / 60000));
  if (m < 1) return "방금";
  if (m < 60) return `${m}분 전`;
  if (m < 60 * 24) return `${Math.floor(m / 60)}시간 전`;
  return `${Math.floor(m / 60 / 24)}일 전`;
}
