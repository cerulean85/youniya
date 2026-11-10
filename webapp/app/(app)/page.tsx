import { WelcomeSheet } from "@/components/WelcomeSheet";
import Link from "next/link";
import { HomeSkeleton } from "@/components/Skeleton";
import { connection } from "next/server";
import { Suspense } from "react";
import { Archive, ChevronRight, Nebula, Pen, Star } from "@/components/icons";
import { StarRow } from "@/components/StarRow";
import { api } from "@/lib/api";
import { getConstellation } from "@/lib/constellation-data";
import { kst, longDate, monthOnly } from "@/lib/format";
import type { Me, StarSummary, Summary } from "@/lib/types";
import { RenameBanner } from "@/components/Restricted";
import styles from "./home.module.css";

// Figma W-10 (오늘, 기획서 21장), W-62 (with the rename banner), W-63 (skeleton) and W-22 (첫 밤하늘 · 비어 있음).
export default function HomePage() {
  return (
    <>
      <header className={styles.header}>
        <h1 className="h1">오늘</h1>
        <Suspense fallback={<p className="body-m muted">&nbsp;</p>}><Today /></Suspense>
      </header>
      <Suspense fallback={null}><OperatorBanners /></Suspense>
      <Suspense fallback={<HomeSkeleton />}>
        <Sky />
      </Suspense>
    </>
  );
}

async function Today() {
  await connection(); // "today" is the request's date, not the build's
  return <p className="body-m muted">{longDate(new Date().toISOString())} · 오늘은 어떤 마음이 머물렀나요?</p>;
}

/** Mobile 04-1: an operator asked for a new 별지기 이름. */
async function OperatorBanners() {
  const me = await api<Me>("/v1/me");
  return me.nickname_rename_required ? <RenameBanner /> : null;
}

async function Sky() {
  await connection();
  const now = kst(new Date());
  const [list, summary, view, me] = await Promise.all([
    api<{ items: StarSummary[] }>("/v1/stars?limit=30"),
    api<Summary>("/v1/stars/summary"),
    getConstellation(now.month),
    api<Me>("/v1/me"),
  ]);
  // W-91: the welcome sheet opens once, over the first empty sky.
  if (summary.total === 0) return <><EmptySky /><WelcomeSheet account={me.id} /></>;
  const c = view?.c ?? null;
  const today = list.items.filter((s) => { const d = kst(s.created_at); return d.y === now.y && d.m === now.m && d.d === now.d; }).length;
  return (
    <div className={styles.body}>
      <div className={styles.left}>
        {/* Figma W-10 (기획서 21장): writing first; the month's figures live on 별자리 (W-16). */}
        <section className={`card ${styles.write}`} aria-labelledby="write-title">
          <div className={styles.writeHead}>
            <h2 id="write-title" className="h3">오늘의 마음은 어떤가요?</h2>
            <span className="caption faint">오늘 띄운 별 {today}개</span>
          </div>
          <p className="body-s muted">하루의 이야기를 편하게 적어 보세요. 다 쓰면 별빛을 받고 띄우거나, 별빛 없이 띄울 수 있어요.</p>
          <Link href="/write" className={`btn btn-primary ${styles.writeButton}`}>오늘의 별 만들기</Link>
          <p className="caption faint">{me.free_star_today > 0 ? `오늘 무료 별빛 ${me.free_star_today}번 남았어요` : "오늘 무료 별빛을 썼어요"} · 별빛 없이 띄우기는 언제나 무료예요</p>
        </section>
        <Link href="/constellation" className={`card ${styles.monthLink}`}>
          <span className="body-s muted">{c ? `${monthOnly(now.month)} ${c.name}자리 · ${c.filled} / ${c.total} 자리 채움` : "이번 달 별자리"}</span>
          <span className={styles.all}>별자리 보기<ChevronRight size={14} /></span>
        </Link>
      </div>
      <section className={styles.recent} aria-labelledby="recent">
        <div className={styles.recentHead}>
          <h2 id="recent" className="label-m muted">최근 별</h2>
          <Link href="/records" className={styles.all}>전체보기<ChevronRight size={14} /></Link>
        </div>
        {list.items.slice(0, 5).map((s) => <StarRow key={s.id} star={s} />)}
      </section>
    </div>
  );
}

function EmptySky() {
  const steps = [
    { icon: <Pen size={20} />, tint: "var(--tint)", color: "var(--primary-text)", title: "1. 오늘의 마음을 적어요", body: "50자를 넘으면 별빛을 받을 수 있어요. 짧은 날은 별빛 없이 띄워요." },
    { icon: <Star size={20} />, tint: "var(--tint-gold)", color: "var(--gold)", title: "2. 별빛 프리즘이 별을 빚어요", body: "마음의 깊이와 선명함, 무게를 읽어 밝기와 색을 정해요." },
    { icon: <Nebula size={20} />, tint: "var(--tint-calm)", color: "var(--calm)", title: "3. 별이 모여 별자리를 채워요", body: "이달의 별자리 자리를 띄운 별로 하나씩 채워요." },
  ];
  return (
    <div className={styles.body}>
      <section className={`card ${styles.empty}`}>
        <div className={styles.waiting} aria-hidden="true"><Star size={36} /></div>
        <h2 className="h2">아직 떠 있는 별이 없어요</h2>
        <p className="body-l muted">마음에 머무는 이야기를 적으면<br />첫 별이 조용히 떠올라요.</p>
        <Link href="/write" className="btn btn-primary">첫 별 만들기</Link>
        <p className="caption faint">별빛 받기는 하루 한 번 무료예요</p>
      </section>
      <section className={styles.recent}>
        <h2 className="label-m muted">처음이라면 이렇게 시작해요</h2>
        {steps.map((s) => (
          <div key={s.title} className={`card ${styles.step}`}>
            <span className={styles.stepIcon} style={{ background: s.tint, color: s.color }}>{s.icon}</span>
            <span><span className="label-m">{s.title}</span><span className="body-s muted" style={{ display: "block" }}>{s.body}</span></span>
          </div>
        ))}
        <Link href="/records" className={styles.all}><Archive size={14} />기록 보기</Link>
      </section>
    </div>
  );
}
