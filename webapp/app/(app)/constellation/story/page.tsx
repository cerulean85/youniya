import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
import { api } from "@/lib/api";
import { MONTH_NAMES } from "@/lib/constellation";
import { dateTime, kst, monthOnly } from "@/lib/format";
import type { Star, StarSummary } from "@/lib/types";
import styles from "./story.module.css";

export const metadata: Metadata = { title: "별자리 이야기" };

type Entry = { star_id: string; date: string; title: string; sentence: string };

// Figma W-40 (390:10724, 기획서 16장 83): the month's key sentences in time order, separated by ✦, never changed.
export default function StoryPage({ searchParams }: PageProps<"/constellation/story">) {
  return (
    <Suspense fallback={<div className={`card ${styles.card}`} style={{ minHeight: 400, opacity: 0.5 }} aria-busy="true" />}>
      <Story searchParams={searchParams} />
    </Suspense>
  );
}

/** Until GET /v1/constellations/{month}/story exists: each star's impact quote, or its first sentence. */
async function entriesFor(month: string): Promise<Entry[]> {
  const { items } = await api<{ items: StarSummary[] }>(`/v1/stars?month=${month}&limit=60`);
  const stars = await Promise.all([...items].sort((a, b) => a.created_at.localeCompare(b.created_at)).map((s) => api<Star>(`/v1/stars/${s.id}`)));
  return stars.map((s) => ({
    star_id: s.id, date: s.created_at, title: s.title,
    sentence: s.analysis?.impact_quote || s.body.split(/(?<=[.!?。…])\s+|\n+/)[0].trim(),
  }));
}

async function Story({ searchParams }: Pick<PageProps<"/constellation/story">, "searchParams">) {
  const sp = await searchParams;
  await connection();
  const month = typeof sp.month === "string" && /^\d{4}-\d{2}$/.test(sp.month) ? sp.month : kst(new Date()).month;
  const entries = await entriesFor(month);
  const name = MONTH_NAMES[month.slice(5)];
  return (
    <>
      <Link href={`/constellation?month=${month}`} className={styles.back}><ChevronLeft size={18} />나의 별자리</Link>
      <article className={`card ${styles.card}`}>
        <p className="caption faint">{monthOnly(month)}{name ? ` · ${name}자리` : ""} · 별 {entries.length}개</p>
        <h1 className="h1">별자리 이야기</h1>
        <p className="body-s muted">별마다 마음이 가장 또렷한 한 문장을 시간 순서로 엮었어요. 문장은 바꾸지 않아요.</p>
        {entries.length === 0 ? <p className="body-m muted">이 달에는 아직 띄운 별이 없어요.</p> : (
          <ol className={styles.entries}>
            {entries.map((e, i) => (
              <li key={e.star_id}>
                {i > 0 && <span className={styles.sep} aria-hidden="true">✦</span>}
                <Link href={`/stars/${e.star_id}`} className={styles.entry} prefetch={false}>
                  <span className="caption faint">{dateTime(e.date)} · {e.title || "제목 없는 별"}</span>
                  <span className="journal">{e.sentence}</span>
                </Link>
              </li>
            ))}
          </ol>
        )}
      </article>
    </>
  );
}
