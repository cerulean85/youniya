import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ConstellationFigure } from "@/components/ConstellationFigure";
import { ChevronRight, Nebula } from "@/components/icons";
import { MONTH_NAMES } from "@/lib/constellation";
import { countDeep, getConstellation } from "@/lib/constellation-data";
import { kst, monthOnly, shiftMonth } from "@/lib/format";
import styles from "./constellation.module.css";

export const metadata: Metadata = { title: "나의 별자리" };

// Figma W-16 (484:13329, 기획서 16장): the month's constellation, filled with that month's stars.
export default function ConstellationPage({ searchParams }: PageProps<"/constellation">) {
  return (
    <Suspense fallback={<><h1 className="h1">나의 별자리</h1><div className={`card ${styles.loading}`} aria-busy="true" /></>}>
      <Month searchParams={searchParams} />
    </Suspense>
  );
}

async function Month({ searchParams }: Pick<PageProps<"/constellation">, "searchParams">) {
  const sp = await searchParams;
  await connection();
  const current = kst(new Date()).month;
  const asked = typeof sp.month === "string" && /^\d{4}-\d{2}$/.test(sp.month) ? sp.month : current;
  const month = asked > current ? current : asked; // no future months
  const { c, stars } = await getConstellation(month);
  const deep = await countDeep(stars);
  const prev = shiftMonth(month, -1), next = shiftMonth(month, 1);
  const name = c?.name ?? MONTH_NAMES[month.slice(5)];
  return (
    <>
      <header className={styles.header}>
        <h1 className="h1">나의 별자리</h1>
        <p className="body-m" style={{ color: "var(--gold)" }}>{monthOnly(month)}{name ? ` · ${name}자리` : ""} · 별 {stars.length}개</p>
      </header>
      <div className={styles.body}>
        <section className={`card ${styles.figureCard}`} aria-label="별자리">
          <div className={styles.figure}>
            {c ? <ConstellationFigure c={c} /> : <p className="body-m muted">{monthOnly(month)} 별자리의 모양을 준비하고 있어요.</p>}
          </div>
          <nav className={styles.months} aria-label="달 넘기기">
            <Link href={`/constellation?month=${prev}`}>‹ {monthOnly(prev)}{MONTH_NAMES[prev.slice(5)] ? ` ${MONTH_NAMES[prev.slice(5)]}` : ""}</Link>
            <span className="label-m">{c ? `${c.filled} / ${c.total}` : ""}</span>
            {month < current ? <Link href={`/constellation?month=${next}`}>{monthOnly(next)}{MONTH_NAMES[next.slice(5)] ? ` ${MONTH_NAMES[next.slice(5)]}` : ""} ›</Link> : <span />}
          </nav>
        </section>
        <aside className={styles.side}>
          <div className={styles.stats}>
            <Stat label="떠 있는 별" value={stars.length} />
            <Stat label="깊은 별" value={deep} />
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
            <span className={`${styles.link} ${styles.soon}`} aria-disabled="true">
              <Nebula size={18} /><span><span className="label-m">나의 은하수</span><span className="caption faint">달마다 채운 별자리를 한눈에 봐요 · 곧 열려요</span></span>
            </span>
          </div>
        </aside>
      </div>
    </>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return <div className={`card ${styles.stat}`}><span className="h1">{value}</span><span className="caption muted">{label}</span></div>;
}
