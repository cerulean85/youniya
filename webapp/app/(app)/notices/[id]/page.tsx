import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
import { api } from "@/lib/api";
import type { Notice } from "@/lib/types";
import styles from "./notice.module.css";

export const metadata: Metadata = { title: "공지" };

// Figma W-59 (Mobile 131 공지 상세): from GET /v1/notices, the published ones.
export default function NoticePage({ params }: PageProps<"/notices/[id]">) {
  return (
    <div className="page-column" style={{ ["--column" as string]: "720px" }}>
      <Link href="/notifications" className={styles.back}><ChevronLeft size={16} />알림</Link>
      <Suspense fallback={<div className={styles.loading} aria-busy="true" />}>
        <Body params={params} />
      </Suspense>
    </div>
  );
}

async function Body({ params }: Pick<PageProps<"/notices/[id]">, "params">) {
  const { id } = await params;
  const { items } = await api<{ items: Notice[] }>("/v1/notices");
  const n = items.find((x) => x.id === id);
  if (!n) notFound();
  const day = new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", year: "numeric", month: "long", day: "numeric" }).format(new Date(n.published_at));
  return (
    <article className={styles.article}>
      <p className="caption faint">{day} · 공지</p>
      <h1 className="h1">{n.title}</h1>
      <div className={`body-l ${styles.body}`}>{n.body}</div>
    </article>
  );
}
