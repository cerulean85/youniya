import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ConstellationFigure } from "@/components/ConstellationFigure";
import { Archive, ChevronRight, Nebula, Pen, Star } from "@/components/icons";
import { StarRow } from "@/components/StarRow";
import { api } from "@/lib/api";
import { getConstellation } from "@/lib/constellation-data";
import { kst, longDate, monthOnly } from "@/lib/format";
import type { StarSummary, Summary } from "@/lib/types";
import styles from "./home.module.css";

// Figma W-10 (나의 밤하늘) and W-22 (첫 밤하늘 · 비어 있음).
export default function HomePage() {
  return (
    <>
      <header className={styles.header}>
        <h1 className="h1">나의 밤하늘</h1>
        <Suspense fallback={<p className="body-m muted">&nbsp;</p>}><Today /></Suspense>
      </header>
      <Suspense fallback={<div className={`card ${styles.loading}`} aria-busy="true" />}>
        <Sky />
      </Suspense>
    </>
  );
}

async function Today() {
  await connection(); // "today" is the request's date, not the build's
  return <p className="body-m muted">{longDate(new Date().toISOString())} · 오늘은 어떤 마음이 머물렀나요?</p>;
}

async function Sky() {
  await connection();
  const month = kst(new Date()).month;
  const [list, summary, view] = await Promise.all([
    api<{ items: StarSummary[] }>("/v1/stars?limit=6"),
    api<Summary>("/v1/stars/summary"),
    getConstellation(month),
  ]);
  if (summary.total === 0) return <EmptySky />;
  const c = view?.c ?? null;
  return (
    <div className={styles.body}>
      <div className={styles.left}>
        <Link href="/constellation" className={`card ${styles.sky}`} aria-label="나의 별자리 보기">
          <div className={styles.skyHead}>
            <h2 className="h3">이번 달 별자리{c ? ` · ${monthOnly(month)} ${c.name}자리` : ""}</h2>
            {c && <span className="caption faint">{c.filled} / {c.total} 자리 채움</span>}
          </div>
          <div className={styles.canvas}>
            {c ? <ConstellationFigure c={c} links={false} /> : <p className="body-m muted">이번 달 별자리의 모양을 준비하고 있어요.</p>}
          </div>
        </Link>
        <div className={styles.stats}>
          <Stat label="이번 달 띄운 별" value={String(view?.count ?? 0)} color="var(--gold)" />
          <Stat label="별빛 없는 별" value={String(view?.unlit ?? 0)} color="var(--text)" />
          <Stat label="채운 자리" value={c ? `${c.filled}/${c.total}` : "–"} color="var(--primary-text)" />
        </div>
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

function Stat({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div className={`card ${styles.stat}`}>
      <span className="caption muted">{label}</span>
      <span className="h1" style={{ color }}>{value}</span>
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
