import type { Metadata } from "next";
import { connection } from "next/server";
import { Suspense } from "react";
import Link from "next/link";
import { PageHeader } from "@/components/Page";
import { api } from "@/lib/api";
import { withAgoAt } from "@/lib/plaza";
import type { AppNotification } from "@/lib/types";
import { readAll } from "./actions";
import { MoreNotifications } from "./More";
import { NotificationRow } from "./Row";
import styles from "./notifications.module.css";

export const metadata: Metadata = { title: "알림" };

const SUB = "운영자 조치와 공지를 모아 둬요. 90일 동안 보관돼요.";

// Figma W-58 (Mobile 130 알림함): operator actions and notices, kept 90 days. A card opens its screen.
export default function NotificationsPage({ searchParams }: PageProps<"/notifications">) {
  return (
    <div className="page-column" style={{ ["--column" as string]: "880px" }}>
      <Suspense fallback={<><PageHeader title="알림" sub={SUB} /><div className={styles.loading} aria-busy="true" /></>}>
        <List searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

async function List({ searchParams }: Pick<PageProps<"/notifications">, "searchParams">) {
  await searchParams;
  const r = await api<{ items: AppNotification[]; unread: number; next_before: string | null }>(
    "/v1/me/notifications?limit=30");
  await connection();
  const rows = withAgoAt(r.items);
  const aside = r.unread > 0 && (
    <form action={readAll}><button className={styles.readAll}>모두 읽음으로 표시</button></form>
  );
  return (
    <>
      <PageHeader title="알림" sub={SUB} aside={aside} />
      {rows.length === 0 ? (
        <div className={styles.empty}>
          <p className="label-m">아직 받은 알림이 없어요</p>
          <p className="body-s muted">운영자 조치와 공지가 생기면 여기에 모여요.</p>
          <Link href="/" className="btn btn-secondary">오늘로 돌아가기</Link>
        </div>
      ) : (
        <div className={styles.wrap}>
          <ul className={styles.list}>
            {rows.map(({ item: n, ago }) => <NotificationRow key={n.id} n={n} ago={ago} />)}
          </ul>
          {r.next_before && <MoreNotifications before={r.next_before} />}
        </div>
      )}
    </>
  );
}
