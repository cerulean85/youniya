import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
import { StarGlyph } from "@/components/StarGlyph";
import { api, ApiError } from "@/lib/api";
import { fullDate, moodOf } from "@/lib/format";
import { requireNickname } from "@/lib/plaza";
import type { PlazaStar } from "@/lib/types";
import { LinePanel, PlazaActions } from "./PlazaActions";
import styles from "./plaza-star.module.css";

export const metadata: Metadata = { title: "다른 이의 별" };

// Figma W-25 (75 다른 이의 별) with W-55 (별빛 한 줄 건네기). The writer's title, their 별지기 이름 (to their
// page), the 대표 문장 and, when they shared it, the whole writing with contacts masked.
export default function PlazaStarPage({ params }: PageProps<"/plaza/stars/[id]">) {
  return (
    <>
      <Link href="/plaza" className={styles.back}><ChevronLeft size={14} />우주 광장</Link>
      <Suspense fallback={<div className={styles.v11} aria-busy="true" style={{ minHeight: 520 }} />}>
        <Detail params={params} />
      </Suspense>
    </>
  );
}

async function Detail({ params }: Pick<PageProps<"/plaza/stars/[id]">, "params">) {
  const { id } = await params;
  const me = await requireNickname(`/plaza/stars/${id}`);
  let star: PlazaStar;
  try {
    star = await api<PlazaStar>(`/v1/plaza/stars/${id}`);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  const keeper = star.nickname ? `/plaza/keepers/${encodeURIComponent(star.nickname)}` : null;
  const restricted = !!me.plaza_restricted_until && new Date(me.plaza_restricted_until) > new Date();
  const mine = !!star.nickname && star.nickname === me.nickname;
  return (
    // Figma 웹 v1.1 · 광장 별 상세 (640:31343): the writing on the left, the star and 별빛 한 줄 on the right.
    <div className={styles.v11}>
      <article className={styles.left}>
        <p className="caption faint">
          {fullDate(star.created_at)} · {keeper ? <Link href={keeper} className={styles.keeperLink}>{star.nickname}의 별</Link> : "익명의 별지기의 별"}
          {" · "}{star.has_starlight ? `깊이 ${star.depth_level}단계` : "별빛 없는 별"}
        </p>
        <h1 className={styles.title}>{star.title_masked ?? star.name}</h1>
        <blockquote className={styles.quote}>“{star.quote}”</blockquote>
        {star.full_text && star.body_masked ? <div className={styles.full}>{star.body_masked}</div>
          : <p className="caption faint">별지기가 골라 나눈 한 문장이에요.</p>}
        <PlazaActions id={star.id} resonated={star.resonated} keeper={keeper} name={star.nickname} mine={mine} restricted={restricted} />
      </article>
      <aside className={styles.right}>
        <div className={styles.hero} aria-hidden="true">
          <span className="v2-glow" style={{ ["--c" as string]: moodOf(star.mood).color, inset: "-20% 10%" }} />
          {star.has_starlight ? <StarGlyph points={star.shape?.points} sharpness={star.shape?.sharpness} mood={star.mood} size={140} twinkle />
            : <span className={styles.unlit} style={{ background: moodOf(star.mood).color, color: moodOf(star.mood).color }} />}
        </div>
        {!mine && <LinePanel id={star.id} restricted={restricted} lines={star.receive_lines ? (star.line_left ? "left" : "open") : "closed"} />}
      </aside>
    </div>
  );
}
