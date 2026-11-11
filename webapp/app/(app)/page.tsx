import { WelcomeSheet } from "@/components/WelcomeSheet";
import Link from "next/link";
import { HomeSkeleton } from "@/components/Skeleton";
import { connection } from "next/server";
import { Suspense } from "react";
import { ConstellationFigure } from "@/components/ConstellationFigure";
import { StarGlyph } from "@/components/StarGlyph";
import { api } from "@/lib/api";
import { getConstellation } from "@/lib/constellation-data";
import { kst, longDate, monthDay, monthOnly, moodOf } from "@/lib/format";
import type { Me, StarSummary, Summary } from "@/lib/types";
import { RenameBanner } from "@/components/Restricted";
import styles from "./home.module.css";

// Figma Web 시안 v2 '하늘이 화면' (2026-11-11): 오늘 590:27781, 첫 밤하늘 596:29807. The page is the sky: the title and
// the writing prompt sit straight on it, today's star is the lead (or the month's empty figure on a first visit).
export default function HomePage() {
  return (
    <div className={styles.page}>
      <Suspense fallback={null}><OperatorBanners /></Suspense>
      <Suspense fallback={<><Heading /><HomeSkeleton /></>}>
        <Sky />
      </Suspense>
    </div>
  );
}

function Heading({ date }: { date?: string }) {
  return (
    <header className={styles.header}>
      <h1 className="v2-hero">오늘</h1>
      <p className="v2-lead">{date ?? "\u00a0"}</p>
    </header>
  );
}

/** Mobile 04-1: an operator asked for a new 별지기 이름. */
async function OperatorBanners() {
  const me = await api<Me>("/v1/me");
  return me.nickname_rename_required ? <RenameBanner /> : null;
}

async function Sky() {
  await connection(); // "today" is the request's date, not the build's
  const now = kst(new Date());
  const [list, summary, view, me] = await Promise.all([
    api<{ items: StarSummary[] }>("/v1/stars?limit=30"),
    api<Summary>("/v1/stars/summary"),
    getConstellation(now.month),
    api<Me>("/v1/me"),
  ]);
  const date = longDate(new Date().toISOString());
  const c = view?.c ?? null;
  const free = me.free_star_today > 0 ? `오늘 무료 별빛 ${me.free_star_today}번` : "오늘 무료 별빛을 썼어요";
  // W-91: the welcome sheet opens once, over the first empty sky.
  if (summary.total === 0) return (
    <>
      <Heading date={date} />
      <section className={styles.top}>
        <div className={styles.prompt}>
          <h2 className="v2-title">아직 비어 있는<br />밤하늘이에요</h2>
          <p className="v2-body">첫 별을 띄우면 {monthOnly(now.month)} {c ? `${c.name}자리` : "별자리"}의 첫 자리가 채워져요. 한 줄이어도 괜찮아요.</p>
          <Link href="/write" className={`btn btn-primary ${styles.cta}`}>첫 별 만들기</Link>
          <p className="v2-meta">{free} · 별빛 없이 띄우기는 언제나 무료예요</p>
        </div>
        {c && (
          <div className={styles.emptySky} aria-hidden="true">
            <span className="v2-glow" style={{ ["--c" as string]: "var(--primary)", inset: "10% 18%" }} />
            <ConstellationFigure c={c} links={false} />
            <span className={styles.firstSlot} style={{ left: `${c.slots[0].x * 100}%`, top: `${c.slots[0].y * 100}%` }} />
            <span className={`v2-link ${styles.firstLabel}`} style={{ left: `${c.slots[0].x * 100}%`, top: `${c.slots[0].y * 100}%` }}>첫 별이 여기에 떠요</span>
          </div>
        )}
      </section>
      <hr className="v2-rule" />
      <ol className={styles.steps}>
        {[["✎", "쓰고", "오늘의 마음을 편하게 적어요"], ["✦", "띄우고", "별빛을 받거나, 그냥 띄워요"], ["☾", "채워요", "한 달이 모여 별자리가 돼요"]].map(([i, t, d]) => (
          <li key={t}><span className={styles.stepIcon} aria-hidden="true">{i}</span><span><b>{t}</b><span className="v2-meta">{d}</span></span></li>
        ))}
      </ol>
      <WelcomeSheet account={me.id} />
    </>
  );
  const isToday = (s: StarSummary) => { const d = kst(s.created_at); return d.y === now.y && d.m === now.m && d.d === now.d; };
  // The lead: the newest star of today, lit first.
  const todays = list.items.filter(isToday);
  const hero = todays.find((s) => s.has_starlight ?? s.state === "floated") ?? todays[0] ?? null;
  const heroMood = hero ? moodOf(hero.mood) : null;
  const lit = (s: StarSummary) => (s.has_starlight ?? s.state === "floated") && s.starlight != null;
  return (
    <>
      <Heading date={date} />
      <section className={styles.top}>
        <div className={styles.prompt}>
          <h2 className="v2-title">오늘의 마음은<br />어떤가요?</h2>
          <p className="v2-body">하루의 이야기를 편하게 적어 보세요. 다 쓰면 별빛을 받고 띄우거나, 별빛 없이 띄울 수 있어요.</p>
          <Link href="/write" className={`btn btn-primary ${styles.cta}`}>오늘의 별 만들기</Link>
          <p className="v2-meta">{free}{me.free_star_today > 0 ? " 남았어요" : ""} · 별빛 없이 띄우기는 언제나 무료예요</p>
        </div>
        <div className={styles.hero}>
          {/* The month's figure, faint, behind today's star. */}
          {c && <div className={styles.heroSky} aria-hidden="true"><ConstellationFigure c={c} links={false} /></div>}
          {hero ? (
            <Link href={`/stars/${hero.id}`} className={styles.heroStar} style={{ ["--c" as string]: heroMood!.color }}>
              <span className="v2-glow" style={{ ["--c" as string]: heroMood!.color, inset: "-35%" }} />
              {lit(hero) ? <StarGlyph points={hero.shape?.points} sharpness={hero.shape?.sharpness} mood={hero.mood} size={236} twinkle />
                : <span className={styles.unlitHero} style={{ background: heroMood!.color }} />}
              <span className={styles.heroCaption}>오늘의 별 · {hero.title || "제목 없는 별"}</span>
              <span className="v2-meta">{lit(hero) ? `별빛 ${hero.starlight}` : "별빛 없는 별"}{hero.shape ? ` · 꼭짓점 ${hero.shape.points}` : ""} · {heroMood!.label}</span>
            </Link>
          ) : (
            <div className={styles.heroStar}>
              <span className={styles.todayRing} aria-hidden="true" />
              <span className={`v2-link ${styles.heroCaption}`}>오늘의 별이 여기에 떠요</span>
            </div>
          )}
        </div>
      </section>
      <section aria-labelledby="recent">
        <div className={styles.recentHead}>
          <h2 id="recent" className="v2-meta">최근 별</h2>
          <Link href="/records" className="v2-link">전체 보기 ›</Link>
        </div>
        <hr className="v2-rule" />
        <ul className={styles.recent}>
          {list.items.slice(0, 4).map((s) => {
            const m = moodOf(s.mood);
            return (
              <li key={s.id}>
                <Link href={`/stars/${s.id}`} className={`v2-hover ${styles.recentItem}`}>
                  <span className="v2-glow" style={{ ["--c" as string]: m.color, width: 150, height: 150, left: -40, top: -36 }} />
                  <span className={styles.recentStar}>
                    {lit(s) ? <StarGlyph points={s.shape?.points} sharpness={s.shape?.sharpness} mood={s.mood} size={34} twinkle />
                      : <StarGlyph points={4} mood={s.mood} size={26} />}
                  </span>
                  <span>
                    <span className="v2-item">{s.title || "제목 없는 별"}</span>
                    <span className="v2-small">{monthDay(s.created_at)} · {lit(s) ? `별빛 ${s.starlight}` : "별빛 없는 별"}</span>
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>
      </section>
      <p className={styles.month}>
        <span className="v2-body">{c ? `${monthOnly(now.month)} ${c.name}자리 · ${c.filled} / ${c.total} 자리 채움` : "이번 달 별자리"}</span>
        <Link href="/constellation" className="v2-link">별자리 보기 ›</Link>
      </p>
    </>
  );
}
