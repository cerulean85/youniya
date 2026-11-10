import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
import { ConstellationSkeleton } from "@/components/Skeleton";
import { api } from "@/lib/api";
import { getConstellation } from "@/lib/constellation-data";
import { kst, moodOf } from "@/lib/format";
import type { Mood, Star } from "@/lib/types";
import { ConstellationZoom } from "./Zoom";
import styles from "./detail.module.css";

export const metadata: Metadata = { title: "별자리 자세히" };

// Figma W-68 (W-16 '자세히 보기'): the month's constellation large, with what it's made of.
export default function DetailPage({ searchParams }: PageProps<"/constellation/detail">) {
  return (
    <Suspense fallback={<ConstellationSkeleton />}>
      <Detail searchParams={searchParams} />
    </Suspense>
  );
}

async function Detail({ searchParams }: Pick<PageProps<"/constellation/detail">, "searchParams">) {
  const sp = await searchParams;
  await connection();
  const current = kst(new Date()).month;
  const month = typeof sp.month === "string" && /^\d{4}-\d{2}$/.test(sp.month) && sp.month <= current ? sp.month : current;
  const view = await getConstellation(month);
  const c = view?.c;
  if (!c) return <p className="body-m muted">아직 열리지 않은 달이에요.</p>;
  const stars = c.slots.flatMap((s) => (s.star ? [s.star] : []));
  const details = await Promise.all(stars.filter((s) => s.has_starlight !== false && s.starlight != null).map((s) => api<Star>(`/v1/stars/${s.id}`).catch(() => null)));
  const depths = details.flatMap((d) => (d?.analysis ? [d.analysis.depth_level] : []));
  const depth = depths.length ? (depths.reduce((a, b) => a + b, 0) / depths.length).toFixed(1) : null;
  const moods = [...new Set(stars.flatMap((s) => (s.moods?.length ? s.moods : [s.mood])))] as Mood[];
  const brightest = stars.filter((s) => s.starlight != null).sort((a, b) => b.starlight! - a.starlight!)[0];
  const day = (iso: string) => `${kst(iso).m}월 ${kst(iso).d}일`;
  return (
    <div className={styles.page}>
      <Link href={`/constellation?month=${month}`} className={styles.back}><ChevronLeft size={16} />나의 별자리</Link>
      <span className={styles.badge}>{Number(month.slice(5))}월 · {c.complete ? "완성" : `채우는 중 ${c.filled} / ${c.total}`}</span>
      <h1 className="h1">{c.name}자리</h1>
      <ConstellationZoom c={c} />
      <dl className={`card ${styles.facts}`}>
        <div><dt>채운 자리</dt><dd>{c.filled} / {c.total}{c.complete ? " · 완성" : ` · ${c.total - c.filled}자리 남음`}</dd></div>
        {depth && <div><dt>평균 깊이</dt><dd>{depth}단계</dd></div>}
        {moods.length > 0 && <div><dt>빛깔</dt><dd>{moods.map((m) => moodOf(m).label).join(" · ")}</dd></div>}
        {brightest && <div><dt>가장 밝은 별</dt><dd>{day(brightest.created_at)} · 별빛 {brightest.starlight}</dd></div>}
      </dl>
      <Link href={`/constellation/story?month=${month}`} className={styles.chip}>별자리 이야기</Link>
    </div>
  );
}
