import type { Metadata } from "next";
import { ConstellationSkeleton } from "@/components/Skeleton";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ConstellationPick } from "@/components/ConstellationPick";
import { ShareCard } from "@/components/ShareCard";
import { NebulaGlow } from "@/components/NebulaGlow";
import { ChevronRight, Nebula } from "@/components/icons";
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
  const old = view?.c?.complete && view.c.slots.some((x) => x.star && !("shape" in x.star));
  const list = old ? await api<{ items: StarSummary[] }>(`/v1/stars?month=${month}&limit=200`).catch(() => null) : null;
  const shapeOf = new Map((list?.items ?? []).map((s) => [s.id, s.shape ?? null]));
  const c = view?.c ?? null, count = view?.count ?? 0;
  const prev = shiftMonth(month, -1), next = shiftMonth(month, 1);
  const hasPrev = !first || prev >= first;
  const name = c?.name ?? MONTH_NAMES[month.slice(5)];
  return (
    <>
      <header className={styles.header}>
        <h1 className="h1">나의 별자리</h1>
        <p className="body-m" style={{ color: "var(--gold)" }}>{monthOnly(month)}{name ? ` · ${name}자리` : ""} · 별 {count}개</p>
      </header>
      <div className={styles.body}>
        <section className={`card ${styles.figureCard}`} aria-label="별자리">
          {/* Mobile: the canvas sits on the sky's nebula glow. */}
          <NebulaGlow />
          {/* 기획서 23장 (Mobile 08-5·08-7 Complete Card Button): only a completed month has a card, and says so. */}
          {c?.complete && <ShareCard kind="constellation" data={constellationCard(c, shapeOf)} label="완성 카드 ›"
            className={styles.completeCard} />}
          <div className={styles.figure}>
            {c ? <ConstellationPick c={c} /> : <p className="body-m muted">{view ? `${monthOnly(month)} 별자리의 모양을 준비하고 있어요.` : "아직 열리지 않은 달이에요."}</p>}
          </div>
          <nav className={styles.months} aria-label="달 넘기기">
            {hasPrev ? <Link href={`/constellation?month=${prev}`}>‹ {monthOnly(prev)}{MONTH_NAMES[prev.slice(5)] ? ` ${MONTH_NAMES[prev.slice(5)]}` : ""}</Link> : <span />}
            <span className="label-m">{c ? `${c.filled} / ${c.total}` : ""}</span>
            {month < current ? <Link href={`/constellation?month=${next}`}>{monthOnly(next)}{MONTH_NAMES[next.slice(5)] ? ` ${MONTH_NAMES[next.slice(5)]}` : ""} ›</Link> : <span />}
          </nav>
        </section>
        <aside className={styles.side}>
          <div className={styles.stats}>
            <Stat label="떠 있는 별" value={count} />
            <Stat label="깊은 별" value={view?.deep ?? 0} />
            <Stat label="남은 자리" value={c ? c.total - c.filled : 0} />
          </div>
          {c && (
            <div className={`card ${styles.progress}`}>
              <div className={styles.progressHead}><span className="label-m">{monthOnly(month)} · {c.name}자리</span><span className="caption faint">{c.filled} / {c.total}</span></div>
              <i style={{ ["--v" as string]: `${(c.filled / c.total) * 100}%` }} />
              <p className="body-s muted">
                {c.complete ? `${monthOnly(month)}의 ${c.name}자리를 모두 채웠어요. 완성이에요.`
                  : `${monthOnly(month)} 저녁 하늘에 뜨는 ${c.name}자리예요. 별을 띄울 때마다 빈 자리가 하나씩 채워지고, ${c.total}개를 다 채우면 완성돼요.`}
              </p>
            </div>
          )}
          <div className={styles.more}>
            <span className="caption faint">더 둘러보기</span>
            <Link href={`/constellation/story?month=${month}`} className={styles.link}>
              <Nebula size={18} /><span><span className="label-m">별자리 이야기</span><span className="caption faint">그달 별들의 핵심 문장을 시간순으로 엮어요</span></span><ChevronRight size={16} />
            </Link>
            {months ? (
              <Link href="/constellation/galaxy" className={styles.link}>
                <Nebula size={18} /><span><span className="label-m">나의 은하수</span><span className="caption faint">달마다 채운 별자리를 한눈에 봐요</span></span><ChevronRight size={16} />
              </Link>
            ) : (
              <span className={`${styles.link} ${styles.soon}`} aria-disabled="true">
                <Nebula size={18} /><span><span className="label-m">나의 은하수</span><span className="caption faint">달마다 채운 별자리를 한눈에 봐요 · 곧 열려요</span></span>
              </span>
            )}
          </div>
        </aside>
      </div>
    </>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return <div className={`card ${styles.stat}`}><span className="h1">{value}</span><span className="caption muted">{label}</span></div>;
}
