import type { Metadata } from "next";
import { ConstellationSkeleton } from "@/components/Skeleton";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ConstellationPick } from "@/components/ConstellationPick";
import { ShareCard } from "@/components/ShareCard";
import { MONTH_NAMES, type Constellation } from "@/lib/constellation";
import { StarGlyph } from "@/components/StarGlyph";
import { api } from "@/lib/api";
import type { StarSummary } from "@/lib/types";
import { getConstellation, listMonths } from "@/lib/constellation-data";
import { kst, monthDay, monthOnly, shiftMonth } from "@/lib/format";
import { constellationCard } from "@/lib/constellation-card";
import styles from "./constellation.module.css";

export const metadata: Metadata = { title: "나의 별자리" };

// Figma W-16 (484:13329, 기획서 16장): the month's constellation, filled with that month's stars.
export default function ConstellationPage({ searchParams }: PageProps<"/constellation">) {
  return (
    <Suspense fallback={<ConstellationSkeleton />}>
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
  const c = view?.c ?? null;
  const prev = shiftMonth(month, -1), next = shiftMonth(month, 1);
  const hasPrev = !first || prev >= first;
  const name = c?.name ?? MONTH_NAMES[month.slice(5)];
  const past = months ? months.filter((m) => m.month < current).length : 0;
  const lit = (x: NonNullable<Constellation["slots"][number]["star"]>) => x.has_starlight !== false && x.starlight != null;
  return (
    <div className={styles.page}>
      {/* Figma 웹 v1.1 · 별자리 (634:30995): the sky on the left, the month's slots as a list beside it. */}
      <section className={styles.sky} aria-label="별자리">
        <div className={styles.head}>
          <div>
            <h1 className="h1">{monthOnly(month)}{name ? ` · ${name}자리` : ""}</h1>
            {c && <p className="body-s muted">{c.complete ? `${c.total}자리를 모두 채웠어요 · 완성이에요` : `${c.total}자리 중 ${c.filled}자리 채움 · ${monthOnly(month)} 저녁 하늘에 뜨는 별자리예요`}</p>}
          </div>
          <nav className={styles.months} aria-label="달 넘기기">
            {hasPrev && <Link href={`/constellation?month=${prev}`}>‹ {monthOnly(prev)}</Link>}
            {month < current && <Link href={`/constellation?month=${next}`}>{monthOnly(next)} ›</Link>}
          </nav>
        </div>
        {/* ④ 브랜드: the canvas is the night sky, so the star field belongs here (and only here). */}
        <div className={styles.canvas}>
          {c ? <ConstellationPick c={c} shapes={shapeOf} /> : <p className="body-s muted">{view ? `${monthOnly(month)} 별자리의 모양을 준비하고 있어요.` : "아직 열리지 않은 달이에요."}</p>}
        </div>
      </section>
      <aside className={styles.slots} aria-labelledby="slots-head">
        {c && (
          <>
            <div className={styles.slotsHead}>
              <h2 id="slots-head" className="label-m muted">채운 자리</h2>
              <span className="label-m muted">{c.filled} / {c.total}</span>
            </div>
            <ol className={styles.list}>
              {c.slots.map((sl) => {
                const x = sl.star;
                if (!x) return (
                  <li key={sl.index} className={styles.emptyRow}><span className={styles.ring} aria-hidden="true" /><span className="body-s faint">빈 자리 · 별을 띄우면 채워져요</span></li>
                );
                const shape = x.shape !== undefined ? x.shape : shapeOf.get(x.id) ?? null;
                return (
                  <li key={sl.index}>
                    <Link href={`/stars/${x.id}`} className={styles.row}>
                      <span className={styles.glyph}>{lit(x) ? <StarGlyph points={shape?.points} sharpness={shape?.sharpness} mood={x.mood} size={24} /> : <StarGlyph points={4} mood={x.mood} size={18} />}</span>
                      <span className={styles.rowText}>
                        <span className={styles.rowTitle}>{x.title || "제목 없는 별"}</span>
                        <span className="caption faint">{monthDay(x.created_at)}</span>
                      </span>
                      <span className={lit(x) ? styles.value : "caption faint"}>{lit(x) ? x.starlight : "별빛 없음"}</span>
                    </Link>
                  </li>
                );
              })}
            </ol>
          </>
        )}
        <div className={styles.more}>
          {/* 기획서 23장: only a completed month has a card, and says so. */}
          {c?.complete && <ShareCard kind="constellation" data={constellationCard(c, shapeOf)} label="완성 카드 만들기 ›" className={styles.link} />}
          <Link href={`/constellation/story?month=${month}`} className={styles.link}>별자리 이야기 · 이달 별에서 고른 문장 ›</Link>
          {months ? <Link href="/constellation/galaxy" className={styles.link}>나의 은하수{past ? ` · 지난 별자리 ${past}개` : ""} ›</Link> : <span className="body-s faint">나의 은하수 · 곧 열려요</span>}
        </div>
      </aside>
    </div>
  );
}
