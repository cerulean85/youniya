import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ConstellationFigure } from "@/components/ConstellationFigure";
import { ChevronLeft } from "@/components/icons";
import { getConstellation, listMonths } from "@/lib/constellation-data";
import { kst, monthOnly } from "@/lib/format";
import styles from "./galaxy.module.css";

export const metadata: Metadata = { title: "나의 은하수" };

// Figma W-57: every month's constellation from sign-up to now, oldest on the left; a card opens that month.
// The silver arcs for 별 잇기 across months wait for API data.
export default function GalaxyPage() {
  return (
    <>
      <Link href="/constellation" className={styles.back}><ChevronLeft size={18} />나의 별자리</Link>
      <Suspense fallback={<><h1 className="h1">나의 은하수</h1><div className={styles.loading} aria-busy="true" /></>}>
        <Galaxy />
      </Suspense>
    </>
  );
}

async function Galaxy() {
  await connection();
  const current = kst(new Date()).month;
  const months = [...((await listMonths()) ?? [])].reverse(); // oldest first
  const views = await Promise.all(months.map((m) => getConstellation(m.month)));
  const complete = months.filter((m) => m.complete).length;
  const first = months[0]?.month;
  return (
    <>
      <header className={styles.header}>
        <h1 className="h1">나의 은하수</h1>
        {first && <p className="body-m" style={{ color: "var(--gold)" }}>{first.slice(0, 4)}년 {monthOnly(first)}부터 · 별자리 {months.length}개 · 완성 {complete}개</p>}
      </header>
      <h2 className="h3">달마다 채운 별자리</h2>
      {months.length === 0 ? <p className="body-m muted">아직 열린 별자리가 없어요.</p> : (
        <ol className={styles.cards}>
          {months.map((m, i) => {
            const c = views[i]?.c;
            const now = m.month === current;
            return (
              <li key={m.month}>
                <Link href={`/constellation?month=${m.month}`} className={styles.card} data-now={now || undefined}>
                  <div className={styles.figure} data-partial={!m.complete || undefined}>{c && <ConstellationFigure c={c} links={false} />}</div>
                  <span className="label-m">{monthOnly(m.month)} · {m.name}</span>
                  <span className={styles.foot}>
                    <span className="caption muted">{m.filled} / {m.total} 자리</span>
                    {m.complete ? <span className={styles.done}>완성</span>
                      : now ? <span className={styles.now}>지금 여기</span>
                      : <span className={styles.left}>남은 자리 {m.total - m.filled}</span>}
                  </span>
                </Link>
              </li>
            );
          })}
        </ol>
      )}
      <p className="caption faint">카드를 누르면 그달의 별자리로 가요. 가입한 달부터 이번 달까지만 보여요.</p>
    </>
  );
}
