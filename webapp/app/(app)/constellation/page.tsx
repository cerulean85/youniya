import type { Metadata } from "next";
import { ConstellationSkeleton } from "@/components/Skeleton";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ConstellationPick } from "@/components/ConstellationPick";
import { ShareCard } from "@/components/ShareCard";
import { ChevronRight, Nebula } from "@/components/icons";
import { MONTH_NAMES, type CStar } from "@/lib/constellation";
import { api } from "@/lib/api";
import type { Mood, StarSummary } from "@/lib/types";
import { getConstellation, listMonths } from "@/lib/constellation-data";
import { kst, monthOnly, moodOf, shiftMonth } from "@/lib/format";
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
  const [view, list] = await Promise.all([
    getConstellation(month),
    // The constellation card draws each star's shape; the month's list carries it (the constellation doesn't).
    api<{ items: StarSummary[] }>(`/v1/stars?month=${month}&limit=200`).catch(() => null),
  ]);
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
            {/* 기획서 23장: 자세히 보기 (W-68·W-69) gave way to pressing a star here and to the constellation card. */}
            {c && <ShareCard kind="constellation" label="별자리 카드 공유" className="btn btn-primary btn-block" data={{
              heading: `${month.slice(0, 4)}년 ${Number(month.slice(5))}월의 별자리`, name: c.name, filled: c.filled, total: c.total, count,
              lines: c.lines,
              slots: c.slots.map((x) => ({ x: x.x, y: x.y, color: x.star ? moodOf(x.star.mood).color : null,
                lit: !!x.star && x.star.has_starlight !== false && x.star.starlight != null, starlight: x.star?.starlight ?? null,
                shape: x.star ? shapeOf.get(x.star.id) ?? null : null,
                date: x.star ? `${kst(x.star.created_at).m}/${kst(x.star.created_at).d}` : null })),
              moods: moodCounts([...c.slots.flatMap((x) => (x.star ? [x.star] : [])), ...c.extra]),
            }} />}
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

/** 평온 2 · 슬픔 2 · …: each star's colour (its first mood), only the moods present, most first. */
function moodCounts(stars: CStar[]) {
  const n = new Map<string, number>();
  for (const s of stars) n.set(s.mood, (n.get(s.mood) ?? 0) + 1);
  return [...n].sort((a, b) => b[1] - a[1]).map(([m, count]) => ({ label: moodOf(m as Mood).label, color: moodOf(m as Mood).color, count }));
}

function Stat({ label, value }: { label: string; value: number }) {
  return <div className={`card ${styles.stat}`}><span className="h1">{value}</span><span className="caption muted">{label}</span></div>;
}
