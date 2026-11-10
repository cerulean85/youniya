import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Star, StarFilled } from "@/components/icons";
import styles from "../login/login.module.css";

export const metadata: Metadata = { title: "잠시 점검 중이에요" };

// iOS 41 (StatusScreens): the API answers 503 maintenance while operators work; writing waits in the draft.
export default function MaintenancePage({ searchParams }: PageProps<"/maintenance">) {
  return (
    <div className={styles.page}>
      <section className={styles.pane} style={{ width: "100%" }}>
        <div className={`card ${styles.card}`}>
          <Link href="/" className={styles.logo}><Star size={22} className={styles.mark} />YOUNIYA</Link>
          <div className={styles.orb} aria-hidden="true"><StarFilled size={56} /></div>
          <h1 className="h1">잠시 점검 중이에요</h1>
          <Suspense fallback={null}><Until searchParams={searchParams} /></Suspense>
          <p className="body-m muted">더 편안한 밤하늘을 위해 손보고 있어요. 쓰던 글은 임시 저장돼 있어요.</p>
          <Link href="/" className="btn btn-primary btn-block">다시 열어 보기</Link>
        </div>
      </section>
    </div>
  );
}

async function Until({ searchParams }: Pick<PageProps<"/maintenance">, "searchParams">) {
  const sp = await searchParams;
  const until = typeof sp.until === "string" ? new Date(sp.until) : null;
  if (!until || Number.isNaN(until.getTime())) return null;
  const t = new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", month: "long", day: "numeric", hour: "numeric", minute: "2-digit" }).format(until);
  return <p className="body-l" style={{ color: "var(--gold)" }}>{t}에 다시 열릴 예정이에요.</p>;
}
