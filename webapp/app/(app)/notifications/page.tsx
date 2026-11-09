import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { PageHeader } from "@/components/Page";
import { api } from "@/lib/api";
import { kindOf, targetHref } from "@/lib/notifications";
import { withAgoAt } from "@/lib/plaza";
import type { AppNotification } from "@/lib/types";
import { readAll } from "./actions";
import styles from "./notifications.module.css";

export const metadata: Metadata = { title: "알림" };

const SUB = "운영자 조치와 공지를 모아 둬요. 90일 동안 보관돼요. 누르면 관련 화면으로 가요.";

// Figma W-58 (Mobile 130 알림함): operator actions and notices, kept 90 days. A card opens its screen.
export default function NotificationsPage({ searchParams }: PageProps<"/notifications">) {
  return (
    <Suspense fallback={<><PageHeader title="알림" sub={SUB} /><div className={styles.loading} aria-busy="true" /></>}>
      <List searchParams={searchParams} />
    </Suspense>
  );
}

async function List({ searchParams }: Pick<PageProps<"/notifications">, "searchParams">) {
  const sp = await searchParams;
  const before = typeof sp.before === "string" ? sp.before : "";
  const r = await api<{ items: AppNotification[]; unread: number; next_before: string | null }>(
    `/v1/me/notifications?limit=30${before ? `&before=${encodeURIComponent(before)}` : ""}`);
  await connection();
  const rows = withAgoAt(r.items);
  const aside = r.unread > 0 && (
    <form action={readAll}><button className="btn btn-secondary">모두 읽음으로 표시</button></form>
  );
  return (
    <>
      <PageHeader title="알림" sub={SUB} aside={aside} />
      {rows.length === 0 ? (
        <p className={`body-m muted ${styles.empty}`}>아직 받은 알림이 없어요. 운영자 조치와 공지가 생기면 여기에 모여요.</p>
      ) : (
        <div className={styles.wrap}>
          <ul className={styles.list}>
            {rows.map(({ item: n, ago }) => {
              const k = kindOf(n), href = targetHref(n.target);
              // 신고 처리 결과 has no link (W-58); everything else opens its screen and is marked read.
              const go = href && k.action ? `/notifications/go?id=${encodeURIComponent(n.id)}&to=${encodeURIComponent(href)}` : null;
              const body = (
                <>
                  <span className={styles.dot} style={{ ["--c" as string]: k.color }} aria-hidden="true" />
                  <span className={styles.text}>
                    <span className={styles.meta}><span style={{ color: k.color }}>{k.label}</span><span className="faint">{ago}</span></span>
                    <span className={styles.title}>{n.title}</span>
                    <span className="body-s muted">{n.body}</span>
                  </span>
                  {go && <span className={styles.action}>{k.action} ›</span>}
                </>
              );
              return (
                <li key={n.id} className={`card ${styles.item}`} data-unread={!n.read || undefined}>
                  {go ? <Link href={go} prefetch={false} aria-label={`${n.title} · ${k.action}`}>{body}</Link> : <div>{body}</div>}
                </li>
              );
            })}
          </ul>
          {r.next_before && <Link href={`/notifications?before=${encodeURIComponent(r.next_before)}`} className={`btn btn-ghost ${styles.more}`}>지난 알림 더 보기</Link>}
        </div>
      )}
    </>
  );
}
