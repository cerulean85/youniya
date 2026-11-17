import { WelcomeSheet } from "@/components/WelcomeSheet";
import Link from "next/link";
import { HomeSkeleton } from "@/components/Skeleton";
import { connection } from "next/server";
import { Suspense } from "react";
import { Toast } from "@/components/Flash";
import { ConstellationPick } from "@/components/ConstellationPick";
import { StarGlyph } from "@/components/StarGlyph";
import { api } from "@/lib/api";
import { getConstellation } from "@/lib/constellation-data";
import { kst, longDate, monthDay, monthOnly } from "@/lib/format";
import type { Draft, Me, StarSummary, Summary } from "@/lib/types";
import { RenameBanner } from "@/components/Restricted";
import { WriteForm } from "./write/WriteForm";
import styles from "./home.module.css";

// 별빛 받기 waits for the prism: the API answers within 55 s, and the browser gives up at 60 s.
export const maxDuration = 120;

// Figma 웹 v1.1 · 오늘 (633:30936) and 빈 오늘 · 첫 밤 (644:31488): 오늘 is the writing desk.
// The editor on the left; this month's constellation and the latest stars beside it.
export default function HomePage({ searchParams }: PageProps<"/">) {
  return (
    <>
      <Suspense fallback={null}><OperatorBanners /></Suspense>
      <Suspense fallback={<HomeSkeleton />}>
        <Desk searchParams={searchParams} />
      </Suspense>
    </>
  );
}

/** Mobile 04-1: an operator asked for a new 별지기 이름. */
async function OperatorBanners() {
  const me = await api<Me>("/v1/me");
  return me.nickname_rename_required ? <RenameBanner /> : null;
}

async function Desk({ searchParams }: Pick<PageProps<"/">, "searchParams">) {
  await connection(); // "today" is the request's date, not the build's
  const now = kst(new Date());
  const [sp, draft, list, summary, view, me] = await Promise.all([
    searchParams,
    api<Draft>("/v1/drafts/current"),
    api<{ items: StarSummary[] }>("/v1/stars?limit=4"),
    api<Summary>("/v1/stars/summary"),
    getConstellation(now.month),
    api<Me>("/v1/me"),
  ]);
  const c = view?.c ?? null;
  // A 고쳐 쓰기 draft belongs to its star; 오늘 picks up only plain writing.
  const own = draft && !draft.source_star_id ? draft : null;
  const lit = (s: StarSummary) => (s.has_starlight ?? s.state === "floated") && s.starlight != null;
  return (
    <div className={styles.desk}>
      <div className={styles.write}>
        <WriteForm draft={own} source={null} freeStarToday={me.free_star_today} coins={me.coins} date={longDate(new Date().toISOString())} />
      </div>
      <aside className={styles.side} aria-label="이번 달과 최근 별">
        <div className={styles.head}>
          <h2 className="h3">{monthOnly(now.month)}{c ? ` · ${c.name}자리` : ""}</h2>
          <Link href="/constellation" className={styles.more}>별자리 보기 ›</Link>
        </div>
        {c && (
          <>
            <Link href="/constellation" className={styles.figure} aria-label={`${c.name}자리 보기`}><ConstellationPick c={c} still /></Link>
            <div className={styles.progress}>
              <p className="body-s muted">
                {c.filled === 0 ? `${c.total}자리 중 0자리 · 첫 별이 첫 자리를 채워요`
                  : c.filled >= c.total ? `${c.total}자리를 모두 채웠어요` : `${c.total}자리 중 ${c.filled}자리 채움 · 남은 ${c.total - c.filled}자리`}
              </p>
              <span className={styles.track}><span style={{ width: `${Math.min(100, (c.filled / c.total) * 100)}%` }} /></span>
            </div>
          </>
        )}
        {summary.total === 0 || list.items.length === 0 ? (
          <div className={styles.empty}>
            <p className="label-m">아직 띄운 별이 없어요</p>
            <p className="body-s muted">왼쪽에 오늘 있었던 일을 적고 띄우면, 여기에 최근 별이 쌓여요.</p>
          </div>
        ) : (
          <section aria-labelledby="recent">
            <div className={styles.recentHead}>
              <h2 id="recent" className="label-m muted">최근 별</h2>
              <Link href="/records" className={styles.more}>기록 전체 ›</Link>
            </div>
            <ul className={styles.recent}>
              {list.items.slice(0, 4).map((s) => (
                <li key={s.id}>
                  <Link href={`/stars/${s.id}`} className={styles.row}>
                    <span className={styles.star}>
                      {lit(s) ? <StarGlyph points={s.shape?.points} sharpness={s.shape?.sharpness} mood={s.mood} size={28} />
                        : <StarGlyph points={4} mood={s.mood} size={22} />}
                    </span>
                    <span className={styles.rowText}>
                      <span className={styles.rowTitle}>{s.title || "제목 없는 별"}</span>
                      <span className="caption faint">{monthDay(s.created_at)} · {lit(s) ? `별빛 ${s.starlight}` : "별빛 없는 별"}</span>
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          </section>
        )}
      </aside>
      {summary.total === 0 && <WelcomeSheet account={me.id} />}
      {sp.stopped === "1" && <Toast title="별빛 받기를 그만뒀어요" sub="무료와 코인은 그대로예요" />}
    </div>
  );
}
