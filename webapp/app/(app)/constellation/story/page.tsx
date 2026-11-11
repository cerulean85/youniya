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
  // Figma Web 시안 v2 · 별자리 이야기 (596:29495): the month's figure at the top right, the sentences in serif on the sky.
  return (
    <div className={styles.page}>
      {c && <div className={styles.figure} aria-hidden="true"><span className="v2-glow" style={{ ["--c" as string]: "var(--primary)", inset: "-20%" }} /><ConstellationPick c={c} still /></div>}
      <Link href={`/constellation?month=${month}`} className={styles.back}>‹ 나의 별자리</Link>
      <header className={styles.header}>
        <h1 className="v2-hero-s">{monthOnly(month)}{name ? ` · ${name}자리` : ""} 이야기</h1>
        <p className="v2-body">별 {entries.length}개{first ? ` · ${monthDay(first.date)}부터` : ""} · 별마다 고른 핵심 문장을 시간순으로 엮었어요. 원문은 한 글자도 바꾸지 않아요.</p>
      </header>
      {entries.length === 0 ? <p className="v2-body">이 달에는 아직 띄운 별이 없어요.</p> : (
        <ol className={styles.entries}>
          {entries.map((e, i) => {
            const color = moodOf(moodOfStar.get(e.star_id ?? "") ?? "calm").color;
            const head = <span className={styles.head}><i style={{ background: color }} />{monthDay(e.date)} · {e.title || "제목 없는 별"}{e.star_id && <span className={styles.chev} aria-hidden="true"> ›</span>}</span>;
            return (
              <li key={e.star_id ?? `gone-${i}`}>
                {i > 0 && <span className={styles.sep} aria-hidden="true">✦</span>}
                {/* Mobile 83 (2026-11-10): an entry opens its star; one whose star is gone is plain text, no ›. */}
                {e.star_id ? (
                  <Link href={`/stars/${e.star_id}`} className={styles.entry} prefetch={false}>{head}<span className={styles.sentence}>“{e.sentence}”</span></Link>
                ) : (
                  <div className={styles.entry}>{head}<span className={styles.sentence}>“{e.sentence}”</span></div>
                )}
              </li>
            );
          })}
        </ol>
      )}
    </div>
  );
}
