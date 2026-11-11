import type { Metadata } from "next";
import { ConstellationSkeleton } from "@/components/Skeleton";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ConstellationPick } from "@/components/ConstellationPick";
import { ShareCard } from "@/components/ShareCard";
import { MONTH_NAMES } from "@/lib/constellation";
import { api } from "@/lib/api";
import type { StarSummary } from "@/lib/types";
import { getConstellation, listMonths } from "@/lib/constellation-data";
import { kst, monthOnly, shiftMonth } from "@/lib/format";
import { constellationCard } from "@/lib/constellation-card";
import styles from "./constellation.module.css";

export const metadata: Metadata = { title: "나의 별자리" };

// Figma W-16 (484:13329, 기획서 16장): the month's constellation, filled with that month's stars.
export default function ConstellationPage({ searchParams }: PageProps<"/constellation">) {
  return (
    <Suspense fallback={<><h1 className="h1">나의 별자리</h1><ConstellationSkeleton /></>}>
      <Month searchParams={searchParams} />
    </Suspense>
  );
}

async function Month({ searchParams }: Pick<PageProps<"/constellation">, "searchParams">) {
  const sp = await searchParams;
  await connection();
  const current = kst(new Date()).month;
  const asked = typeof sp.month === "string" && /^\d{4}-\d{2}$/.test(sp.month) ? sp.month : current;
  // From the month of sign-up (the oldest the server lists) to this month; never the future.
  const months = await listMonths();
  const first = months?.at(-1)?.month;
  const month = asked > current ? current : first && asked < first ? first : asked;
  const view = await getConstellation(month);
  // The constellation card draws each star's shape. Servers from 21866a6 send it with the constellation;
  // before that, the month's star list has it.
  const old = view?.c?.slots.some((x) => x.star && !("shape" in x.star));
  const list = old ? await api<{ items: StarSummary[] }>(`/v1/stars?month=${month}&limit=200`).catch(() => null) : null;
  const shapeOf = new Map((list?.items ?? []).map((s) => [s.id, s.shape ?? null]));
  const c = view?.c ?? null, count = view?.count ?? 0;
  const prev = shiftMonth(month, -1), next = shiftMonth(month, 1);
  const hasPrev = !first || prev >= first;
  const name = c?.name ?? MONTH_NAMES[month.slice(5)];
  const remaining = c ? c.total - c.filled : 0;
  return (
    <>
      {/* Figma Web 시안 v2 · 별자리 (591:28041): the figure is the lead, nearly the width of the page. */}
      <header className={styles.header}>
        <h1 className="v2-hero-s">{monthOnly(month)}{name ? ` · ${name}자리` : ""}</h1>
        {c && <p className={styles.gold}>{c.complete ? `${c.total}자리를 모두 채웠어요 · 별 ${count}개` : `${c.total}자리 중 ${c.filled}자리를 채웠어요 · 별 ${count}개`}</p>}
        {c && <p className="v2-body">{c.complete ? `${monthOnly(month)}의 ${c.name}자리를 모두 채웠어요. 완성이에요.`
          : `${monthOnly(month)} 저녁 하늘에 뜨는 ${c.name}자리예요. 별을 띄울 때마다 빈 자리가 하나씩 채워져요.`}</p>}
      </header>
      <section className={styles.stage} aria-label="별자리">
        <span className="v2-glow" style={{ ["--c" as string]: "var(--primary)", inset: "-10% 5% 0" }} />
        <span className="v2-glow" style={{ ["--c" as string]: "var(--calm)", left: "5%", top: "40%", width: "45%", height: "70%" }} />
        {/* 기획서 23장 (Mobile 08-5·08-7 Complete Card Button): only a completed month has a card, and says so. */}
        {c?.complete && <ShareCard kind="constellation" data={constellationCard(c, shapeOf)} label="완성 카드 ›" className={styles.completeCard} />}
        <div className={styles.figure}>
          {c ? <ConstellationPick c={c} shapes={shapeOf} /> : <p className="v2-body">{view ? `${monthOnly(month)} 별자리의 모양을 준비하고 있어요.` : "아직 열리지 않은 달이에요."}</p>}
        </div>
        <nav className={styles.months} aria-label="달 넘기기">
          {hasPrev ? <Link href={`/constellation?month=${prev}`}>‹ {monthOnly(prev)}{MONTH_NAMES[prev.slice(5)] ? ` ${MONTH_NAMES[prev.slice(5)]}` : ""}</Link> : <span />}
          {month < current ? <Link href={`/constellation?month=${next}`}>{monthOnly(next)}{MONTH_NAMES[next.slice(5)] ? ` ${MONTH_NAMES[next.slice(5)]}` : ""} ›</Link> : <span />}
        </nav>
      </section>
      <hr className="v2-rule" />
      <div className={styles.foot}>
        <dl className={styles.stats}>
          <Stat label="떠 있는 별" value={count} />
          <Stat label="깊은 별" value={view?.deep ?? 0} />
          <Stat label="남은 자리" value={remaining} />
        </dl>
        <div className={styles.more}>
          <Link href={`/constellation/story?month=${month}`} className="v2-link">별자리 이야기 ›</Link>
          {months ? <Link href="/constellation/galaxy" className="v2-link">나의 은하수 ›</Link> : <span className="v2-meta">나의 은하수 · 곧 열려요</span>}
        </div>
      </div>
    </>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return <div className={styles.stat}><dd>{value}</dd><dt className="v2-meta">{label}</dt></div>;
}
