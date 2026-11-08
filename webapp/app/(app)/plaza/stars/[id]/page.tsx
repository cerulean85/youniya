import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
import { StarGlyph } from "@/components/StarGlyph";
import { api, ApiError } from "@/lib/api";
import type { PlazaStar } from "@/lib/types";
import { PlazaActions } from "./PlazaActions";
import styles from "./plaza-star.module.css";

export const metadata: Metadata = { title: "다른 이의 별" };

// Figma W-25 (75 다른 이의 별). Shown as its own page on the web.
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
  let star: PlazaStar;
  try {
    star = await api<PlazaStar>(`/v1/plaza/stars/${id}`);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  return (
    <article className={`card ${styles.card}`}>
      <header className={styles.head}>
        <h1 className="h2">{star.name}</h1>
        <div className={styles.tags}>
          <span className={styles.tag}>익명의 별지기</span>
          <span className={`${styles.tag} ${styles.gold}`}>깊이 {star.depth_level}단계</span>
        </div>
      </header>
      <div className={styles.sky}><StarGlyph points={star.shape?.points} sharpness={star.shape?.sharpness} mood={star.mood} size={120} /></div>
      <blockquote className={styles.quote}>
        <p className="observation">“{star.quote}”</p>
        <p className="caption faint">본인이 골라 공개한 한 문장이에요. 글 전체는 나가지 않아요.</p>
      </blockquote>
      <PlazaActions id={star.id} resonated={star.resonated} beside={star.beside} />
    </article>
  );
}
