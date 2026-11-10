import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
import { StarGlyph } from "@/components/StarGlyph";
import { api, ApiError } from "@/lib/api";
import { longDate } from "@/lib/format";
import { requireNickname } from "@/lib/plaza";
import type { PlazaStar } from "@/lib/types";
import { PlazaActions } from "./PlazaActions";
import styles from "./plaza-star.module.css";

export const metadata: Metadata = { title: "다른 이의 별" };

// Figma W-25 (75 다른 이의 별) with W-55 (별빛 한 줄 건네기). The writer's title, their 별지기 이름 (to their
// page), the 대표 문장 and, when they shared it, the whole writing with contacts masked.
export default function PlazaStarPage({ params }: PageProps<"/plaza/stars/[id]">) {
  return (
    <>
      <Link href="/plaza" className={styles.back}><ChevronLeft size={18} />우주 광장</Link>
      <Suspense fallback={<div className={`card ${styles.card}`} aria-busy="true" style={{ minHeight: 520 }} />}>
        <Detail params={params} />
      </Suspense>
    </>
  );
}

async function Detail({ params }: Pick<PageProps<"/plaza/stars/[id]">, "params">) {
  const { id } = await params;
  await requireNickname(`/plaza/stars/${id}`);
  let star: PlazaStar;
  try {
    star = await api<PlazaStar>(`/v1/plaza/stars/${id}`);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  const keeper = star.nickname ? `/plaza/keepers/${encodeURIComponent(star.nickname)}` : null;
  return (
    <article className={`card ${styles.card}`}>
      {/* W-25 (2026-11-10): a 56×56 thumbnail beside the title instead of the big star picture. */}
      <header className={styles.head}>
        <span className={styles.thumb} data-unlit={!star.has_starlight || undefined}>
          <StarGlyph points={star.has_starlight ? star.shape?.points : 4} sharpness={star.shape?.sharpness} mood={star.mood} size={star.has_starlight ? 34 : 22} />
        </span>
        <div className={styles.headText}>
        <p className="caption faint">{longDate(star.created_at)}</p>
        <h1 className="h2">{star.title_masked ?? star.name}</h1>
        <div className={styles.tags}>
          {keeper && <Link href={keeper} className={styles.tag}>{star.nickname}</Link>}
          {star.has_starlight ? <span className={`${styles.tag} ${styles.gold}`}>깊이 {star.depth_level}단계</span>
            : <span className={styles.tag}>별빛 없는 별</span>}
        </div>
        </div>
      </header>
      <blockquote className={styles.quote}>
        <p className="observation">“{star.quote}”</p>
        <p className="caption faint">{star.full_text ? "대표 문장과 글 전체가 별지기 이름과 함께 공개된 별이에요." : "별지기가 골라 나눈 한 문장이에요."}</p>
      </blockquote>
      {star.full_text && star.body_masked && <div className={`journal ${styles.full}`}>{star.body_masked}</div>}
      <PlazaActions id={star.id} resonated={star.resonated} beside={star.beside} keeper={keeper} name={star.nickname}
        lines={star.receive_lines ? (star.line_left ? "left" : "open") : "closed"} />
    </article>
  );
}
