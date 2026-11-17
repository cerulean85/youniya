import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ConstellationPick } from "@/components/ConstellationPick";
import { getConstellation, getStory } from "@/lib/constellation-data";
import { MONTH_NAMES } from "@/lib/constellation";
import { kst, monthDay, monthOnly, moodOf } from "@/lib/format";
import styles from "./story.module.css";

export const metadata: Metadata = { title: "별자리 이야기" };

// Figma W-40 (390:10724, 기획서 16장 83): the month's key sentences in time order, separated by ✦, never changed.
export default function StoryPage({ searchParams }: PageProps<"/constellation/story">) {
  return (
    <Suspense fallback={<div className={styles.loading} aria-busy="true" />}>
      <Story searchParams={searchParams} />
    </Suspense>
  );
}

async function Story({ searchParams }: Pick<PageProps<"/constellation/story">, "searchParams">) {
  const sp = await searchParams;
  await connection();
  const month = typeof sp.month === "string" && /^\d{4}-\d{2}$/.test(sp.month) ? sp.month : kst(new Date()).month;
  const [story, view] = await Promise.all([getStory(month), getConstellation(month).catch(() => null)]);
  const entries = story ?? [];
  const c = view?.c ?? null;
  const name = MONTH_NAMES[month.slice(5)];
  const moodOfStar = new Map([...(c?.slots ?? []).flatMap((x) => (x.star ? [x.star] : [])), ...(c?.extra ?? [])].map((x) => [x.id, x.mood]));
  const first = entries[0];
  // Figma 웹 v1.1 · 별자리 이야기 (641:31393): a timeline of the sentences on the left; the figure and where it
  // stands beside it.
  return (
    <div className={styles.page}>
      <div className={styles.main}>
        <Link href={`/constellation?month=${month}`} className={styles.back}>‹ 나의 별자리</Link>
        <header className={styles.header}>
          <h1 className="h1">{monthOnly(month)}{name ? ` · ${name}자리` : ""} 이야기</h1>
          <p className="body-s muted">별 {entries.length}개{first ? ` · ${monthDay(first.date)}부터` : ""} · 별마다 고른 핵심 문장을 시간순으로 엮었어요. 원문은 한 글자도 바꾸지 않아요.</p>
        </header>
        {entries.length === 0 ? (
          <div className={styles.empty}>
            <p className="label-m">이 달에는 아직 띄운 별이 없어요</p>
            <p className="body-s muted">별을 띄우면 그 별에서 고른 문장이 여기에 차례로 쌓여요.</p>
            <Link href="/" className="btn btn-secondary">오늘의 별 쓰기</Link>
          </div>
        ) : (
          <ol className={styles.entries}>
            {entries.map((e, i) => {
              const color = moodOf(moodOfStar.get(e.star_id ?? "") ?? "calm").color;
              const body = (
                <>
                  <span className={styles.date}><i style={{ background: color }} />{monthDay(e.date)}</span>
                  <span className={styles.text}>
                    <span className="caption muted">{e.title || "제목 없는 별"}{e.star_id && <span className={styles.chev} aria-hidden="true"> ✦</span>}</span>
                    <span className={styles.sentence}>“{e.sentence}”</span>
                  </span>
                </>
              );
              return (
                <li key={e.star_id ?? `gone-${i}`}>
                  {/* Mobile 83 (2026-11-10): an entry opens its star; one whose star is gone is plain text. */}
                  {e.star_id ? <Link href={`/stars/${e.star_id}`} className={styles.entry} prefetch={false}>{body}</Link> : <div className={styles.entry}>{body}</div>}
                </li>
              );
            })}
          </ol>
        )}
      </div>
      <aside className={styles.side}>
        {c && <div className={styles.figure} aria-hidden="true"><ConstellationPick c={c} still /></div>}
        {c && <p className="label-m">{c.name}자리 · {c.total}자리 중 {c.filled}자리</p>}
        <p className="body-s muted">문장을 누르면 그 별의 글 전체로 가요.{c && !c.complete ? ` 남은 ${c.total - c.filled}자리가 채워지면 이번 달 별자리가 완성돼요.` : ""}</p>
        <Link href={`/constellation?month=${month}`} className="btn btn-secondary btn-block">나의 별자리 보기</Link>
      </aside>
    </div>
  );
}
