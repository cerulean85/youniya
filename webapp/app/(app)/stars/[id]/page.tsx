import type { Metadata } from "next";
import { StarSkeleton } from "@/components/Skeleton";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft, Heart, StarFilled, Warn } from "@/components/icons";
import { StarCard } from "@/components/StarCard";
import { StarlightReading } from "@/components/StarlightReading";
import { api, ApiError } from "@/lib/api";
import { kst, longDate, moodOf, dateTime, MIN_FLOAT_LENGTH } from "@/lib/format";
import type { Me, MyShare, Star, StarSummary } from "@/lib/types";
import { LinkStar } from "./LinkStar";
import { ShareStar } from "./ShareStar";
import { CrisisCare } from "@/components/CrisisCare";
import { ShareCard } from "@/components/ShareCard";
import { CompleteSheet } from "@/components/CompleteSheet";
import { getConstellation } from "@/lib/constellation-data";
import { constellationCard } from "@/lib/constellation-card";
import { MONTH_NAMES } from "@/lib/constellation";
import { StarBirth } from "@/components/StarBirth";
import { StatusScreen } from "@/components/Status";
import { DeleteButton, ExportButton, FloatButton, LinkedChip, RetryFloat, Toast } from "./StarActions";
import { ReceivedLines } from "./ReceivedLines";
import styles from "./star.module.css";

export const metadata: Metadata = { title: "별 상세" };
// 별빛 받기 waits for the prism: the API answers within 55 s, and the browser gives up at 60 s.
export const maxDuration = 120;

// Figma W-54 (별빛 받은 별: 별빛 풀이, 이어진 별; 2026-11-10 마음 망원경은 없앴어요), W-32 (별빛 없는 별) with W-56 (별빛 받기 확인),
// W-24 (별이 떠올랐어요, ?new=1), W-36 (마음 돌봄, ?care=1); ?kept=1 says 별빛 없이 띄웠어요.
export default function StarPage({ params, searchParams }: PageProps<"/stars/[id]">) {
  return (
    <>
      <Link href="/" className={styles.back}><ChevronLeft size={18} />오늘</Link>
      <Suspense fallback={<StarSkeleton />}>
        <StarView params={params} searchParams={searchParams} />
      </Suspense>
    </>
  );
}

async function StarView({ params, searchParams }: Pick<PageProps<"/stars/[id]">, "params" | "searchParams">) {
  const [{ id }, sp] = await Promise.all([params, searchParams]);
  let star: Star;
  try {
    star = await api<Star>(`/v1/stars/${id}`);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  const [me, shares] = await Promise.all([
    api<Me>("/v1/me"),
    star.shared ? api<{ stars: MyShare[] }>("/v1/me/shares").catch(() => null) : null,
  ]);
  const quoteMissing = Boolean(shares?.stars.find((x) => x.star_id === star.id)?.quote_missing);
  const floated = (star.has_starlight ?? star.state === "floated") && star.analysis;
  const linked = star.linked_stars ?? [];
  const title = star.title || "제목 없는 별";
  const justFloated = sp.new === "1" && floated;
  const care = sp.care === "1";
  const mood = moodOf(star.mood);
  // W-85 별을 읽지 못했어요: right after a reading that failed.
  if (sp.failed === "1" && star.analysis_failed && !floated) return (
    <StatusScreen icon={<Warn size={22} />} title="별을 읽지 못했어요" body="글은 그대로 보관되고, 코인도 차감되지 않았어요.">
      <RetryFloat id={star.id} />
      <Link href={`/stars/${star.id}?kept=1`} className="btn btn-secondary btn-block">별빛 없이 띄우기</Link>
    </StatusScreen>
  );
  // 기획서 23장: the star that fills its month's last slot is followed by the 완성 sheet (Mobile 08-10).
  const completed = (justFloated || sp.kept === "1") ? await completedBy(star) : null;
  // W-102: the birth plays once over the new star, lit or not.
  if (justFloated) return <><StarBirth id={star.id} shape={star.analysis?.shape} color={mood.color} /><Result star={star} />{completed}</>;
  return (
    <div className={styles.body}>
      <article className={styles.article}>
        {justFloated && <p className={styles.born}><StarFilled size={16} />별이 떠올랐어요</p>}
        <p className="caption faint">{longDate(star.created_at)} · {dateTime(star.created_at).split(" · ")[1]}</p>
        <h1 className="display">{title}</h1>
        <div className={styles.meta}>
          <span className={styles.mood} style={{ ["--c" as string]: mood.color }}>{mood.label}</span>
          {!floated && <span className="label-s muted">{star.analysis_failed ? "별빛을 읽지 못한 별 · 다시 받을 수 있어요" : "별빛 없는 별"}</span>}
        </div>
        {care && <CrisisCare />}
        {care && (
          <div className={styles.care} role="note">
            <Heart size={20} />
            <div>
              <p className="label-m">지금 많이 힘드신가요?</p>
              <p className="body-s muted">혼자 견디지 않아도 괜찮아요. 109(자살예방 상담전화)가 24시간 열려 있어요. 이 글은 쓴 그대로 남겨 두었어요.</p>
            </div>
          </div>
        )}
        <div className={`journal ${styles.text}`}>{star.body}</div>
      </article>
      <aside className={styles.side}>
        {floated ? (
          <>
            <StarCard analysis={star.analysis!} />
            <StarlightReading analysis={star.analysis!} readAt={star.created_at} version={star.prism_version} />
          </>
        ) : (
          <div className={styles.kept}>
            <p className="body-s muted">
              {star.analysis_failed ? "별빛을 읽지 못했어요. 코인은 차감되지 않았어요. 다시 받으면 별빛 프리즘이 한 번 더 읽어요."
                : "별빛 없이 띄운 별이에요. 별빛을 받으면 별빛 풀이를 볼 수 있어요."}
            </p>
            {!care && (star.body.trim().length >= MIN_FLOAT_LENGTH
              ? <FloatButton id={star.id} free={me.free_star_today > 0} coins={me.coins} />
              : <p className="caption faint">별빛은 {MIN_FLOAT_LENGTH}자부터 받을 수 있어요. 글을 조금 더 써 보세요.</p>)}
            <p className={`caption faint ${styles.keptNote}`}>
              {me.free_star_today > 0 ? "오늘 무료 별빛 받기가 1번 남았어요. 이후 한 번에 5코인이에요." : "오늘 무료 별빛 받기를 썼어요. 한 번에 5코인이에요."}
            </p>
            <Link href={`/stars/${star.id}/edit`} className="btn btn-secondary btn-block">글 수정</Link>
            <ShareStar id={star.id} title={title} body={star.body} shared={star.shared} lit={false} nickname={me.nickname ?? null} quoteMissing={quoteMissing} />
          </div>
        )}
        {(star.shared || (star.line_count ?? 0) > 0) && (
          <Suspense fallback={null}><ReceivedLines id={star.id} shared={star.shared} /></Suspense>
        )}
        {linked.length > 0 && (
          <section className={styles.linked} aria-label="이어진 별">
            <span className="label-m">이어진 별 {linked.length}</span>
            <div className={styles.chips}>{linked.map((l) => <LinkedChip key={l.id} id={star.id} star={l} />)}</div>
          </section>
        )}
        {floated && (
          <>
            <LinkStar id={star.id} title={title} linkedIds={linked.map((l) => l.id)} />
            <ShareStar id={star.id} title={title} body={star.body} shared={star.shared} lit nickname={me.nickname ?? null} quoteMissing={quoteMissing} />
          </>
        )}
        <div className={styles.footerLinks}>
          <ExportButton title={title} date={dateTime(star.created_at)} body={star.body} />
          {/* 기획서 22장: the star card, never the writing. */}
          <ShareCard kind="star" title={title} data={{
            date: `${kst(star.created_at).m}월 ${kst(star.created_at).d}일`,
            month: `${kst(star.created_at).m}월 ${MONTH_NAMES[kst(star.created_at).month.slice(5)] ?? ""}자리`,
            title: null, color: mood.color,
            shape: floated ? star.analysis?.shape ?? null : null,
            starlight: floated ? star.analysis!.starlight : null,
            moods: (floated ? star.analysis!.moods.map((m) => m.mood) : star.moods ?? [star.mood]).map((m) => ({ label: moodOf(m).label, color: moodOf(m).color })),
          }} />
          {floated && <Link href={`/write?rewrite=${star.id}`} className="btn btn-ghost">고쳐 쓰기</Link>}
          <DeleteButton id={star.id} title={title} />
        </div>
      </aside>
      {sp.stopped === "1" && <Toast title="별빛 받기를 그만뒀어요" sub="무료와 코인은 그대로예요" />}
      {sp.kept === "1" && <><StarBirth id={star.id} unlit={mood.color} /><Toast title="별빛 없이 띄웠어요" />{completed}</>}
    </div>
  );
}

/** The 완성 sheet when this star took the last slot of its month's constellation. */
async function completedBy(star: Star) {
  const month = kst(star.created_at).month;
  const view = await getConstellation(month).catch(() => null);
  const c = view?.c;
  if (!c?.complete || c.slots.at(-1)?.star?.id !== star.id) return null;
  // Servers before API 21866a6 send no shapes with the constellation; the month's list has them.
  const old = c.slots.some((x) => x.star && !("shape" in x.star));
  const list = old ? await api<{ items: StarSummary[] }>(`/v1/stars?month=${month}&limit=200`).catch(() => null) : null;
  const shapeOf = new Map((list?.items ?? []).map((x) => [x.id, x.shape ?? null]));
  return <CompleteSheet data={constellationCard(c, shapeOf)} monthLabel={`${Number(month.slice(5))}월`} />;
}

// Figma W-24 (별이 떠올랐어요) with the 별빛 풀이 open. Sections come in 0.2 s apart, rising over 0.5 s, then
// the reading's lines 0.18 s apart: about 3.5 s in all, or all at once with reduced motion (기획서 17.4).
function Result({ star }: { star: Star }) {
  const a = star.analysis!;
  const at = (i: number) => ({ ["--i" as string]: i });
  return (
    <div className={styles.result}>
      <div className={styles.resultCard} style={at(0)} data-rise>
        <StarCard analysis={a} />
      </div>
      <div className={styles.resultSide}>
        <p className={styles.born} style={at(1)} data-rise><StarFilled size={16} />{longDate(star.created_at).replace(/ [^ ]+요일$/, "")} · {star.title || "제목 없는 별"}</p>
        <h1 className="display" style={at(2)} data-rise>별이 떠올랐어요</h1>
        <p className="body-l muted" style={at(3)} data-rise>오늘의 별이 이번 달 별자리의 빈 자리를 채웠어요.</p>
        <div className={styles.resultActions} style={at(5)} data-rise>
          <Link href="/constellation" className="btn btn-primary">나의 별자리 보기</Link>
        </div>
        <Link href={`/stars/${star.id}`} className={styles.shareLink} style={at(6)} data-rise>우주 광장에 나누기</Link>
        <StarlightReading analysis={a} readAt={star.created_at} version={star.prism_version} open animate />
      </div>
    </div>
  );
}
