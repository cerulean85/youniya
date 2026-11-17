import type { Metadata } from "next";
import { StarSkeleton } from "@/components/Skeleton";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft, Heart, Warn } from "@/components/icons";
import { StarGlyph } from "@/components/StarGlyph";
import { StarlightReading } from "@/components/StarlightReading";
import { api, ApiError } from "@/lib/api";
import { fullDate, kst, longDate, moodOf, dateTime, MIN_FLOAT_LENGTH } from "@/lib/format";
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
      <Link href="/records" className={styles.back}><ChevronLeft size={14} />기록</Link>
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
  if (justFloated) {
    const view = await getConstellation(kst(star.created_at).month).catch(() => null);
    const slot = view?.c && view.c.slots.some((x) => x.star?.id === star.id) ? { name: view.c.name, filled: view.c.filled, total: view.c.total } : null;
    return <><StarBirth id={star.id} shape={star.analysis?.shape} color={mood.color} /><Result star={star} slot={slot} />{completed}</>;
  }
  const a = floated ? star.analysis! : null;
  const shape = a?.shape ?? star.shape ?? null;
  const meters = a ? [
    { label: "별의 깊이", v: a.scores?.depth ?? Math.round(a.depth * 400), max: 400, color: "#8b5cf6" },
    { label: "빛의 선명함", v: a.scores?.clarity ?? Math.round(a.clarity * 300), max: 300, color: "#22d3ee" },
    { label: "마음의 무게", v: a.scores?.weight ?? Math.round(a.weight * 300), max: 300, color: "#ec4899" },
  ] : [];
  const when = kst(star.created_at);
  const monthName = MONTH_NAMES[when.month.slice(5)];
  const moods = floated ? a!.moods.map((m) => m.mood) : star.moods ?? [star.mood];
  return (
    // Figma 웹 v1.1 · 별 상세 (634:31404): the writing on the left with its actions in one row under it;
    // a hairline, then this star, its starlight and the reading on the right.
    <div className={styles.v11}>
      <article className={styles.left}>
        <p className="caption faint">{longDate(star.created_at)} · {dateTime(star.created_at).split(" · ")[1]}{monthName ? ` · ${monthName}자리` : ""}</p>
        <h1 className={styles.title}>{title}</h1>
        <div className={styles.moodChips}>
          {moods.map((m) => <span key={m} className={styles.moodChip} style={{ ["--c" as string]: moodOf(m).color }}>{moodOf(m).label}</span>)}
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
        <div className={styles.text}>{star.body}</div>
        {(star.shared || (star.line_count ?? 0) > 0) && (
          <Suspense fallback={null}><ReceivedLines id={star.id} shared={star.shared} /></Suspense>
        )}
        {linked.length > 0 && (
          <section className={styles.linked} aria-label="이어진 별">
            <span className="label-m muted">이어진 별 {linked.length}</span>
            <div className={styles.chips}>{linked.map((l) => <LinkedChip key={l.id} id={star.id} star={l} />)}</div>
          </section>
        )}
        <div className={styles.bar}>
          <ShareStar id={star.id} title={title} body={star.body} shared={star.shared} lit={!!floated} nickname={me.nickname ?? null} quoteMissing={quoteMissing} />
          {floated && <span className={styles.quiet}><LinkStar id={star.id} title={title} linkedIds={linked.map((l) => l.id)} /></span>}
          <div className={styles.textLinks}>
            {floated && <Link href={`/write?rewrite=${star.id}`} className="btn btn-ghost">고쳐 쓰기</Link>}
            {!floated && <Link href={`/stars/${star.id}/edit`} className="btn btn-ghost">글 수정</Link>}
            {/* 기획서 22장: the star card, never the writing. */}
            <ShareCard kind="star" title={title} label="카드 공유" data={{
              date: `${when.m}월 ${when.d}일`,
              month: `${when.m}월 ${monthName ?? ""}자리`,
              title: null, color: mood.color,
              shape: floated ? star.analysis?.shape ?? null : null,
              starlight: floated ? star.analysis!.starlight : null,
              moods: moods.map((m) => ({ label: moodOf(m).label, color: moodOf(m).color })),
            }} />
            <ExportButton title={title} date={dateTime(star.created_at)} body={star.body} />
          </div>
          <span className={styles.del}><DeleteButton id={star.id} title={title} /></span>
        </div>
      </article>
      <aside className={styles.right}>
        <div className={styles.hero} aria-hidden="true">
          <span className="v2-glow" style={{ ["--c" as string]: mood.color, inset: "-25% 0" }} />
          {floated ? <StarGlyph points={shape?.points} sharpness={shape?.sharpness} mood={star.mood} size={200} twinkle />
            : <span className={styles.unlitHero} style={{ background: mood.color, color: mood.color }} />}
        </div>
        <p className="caption faint">
          {floated && shape ? `꼭짓점 ${shape.points} · ${SHARP[shape.sharpness] ?? "보통 뾰족함"} · ` : floated ? "" : "별빛 없는 별 · "}{mood.label}
        </p>
        {a ? (
          <section className={styles.reading} aria-label="별빛">
            <p className={styles.starlight}><b>{a.starlight}</b><span>별빛</span></p>
            <p className={styles.observation}>“{a.observation}”</p>
            {meters.map((m) => (
              <div key={m.label} className={styles.meter}>
                <span>{m.label}</span><span className="caption faint">{m.v} / {m.max}</span>
                <i style={{ ["--v" as string]: `${Math.min(100, (m.v / m.max) * 100)}%`, ["--c" as string]: m.color }} />
              </div>
            ))}
            <StarlightReading analysis={a} readAt={star.created_at} version={star.prism_version} />
          </section>
        ) : (
          <section className={styles.keptV2}>
            <p className="body-s muted">
              {star.analysis_failed ? "별빛을 읽지 못했어요. 코인은 차감되지 않았어요. 다시 받으면 별빛 프리즘이 한 번 더 읽어요."
                : "별빛 없이 띄운 별이에요. 별빛을 받으면 별빛과 별빛 풀이를 볼 수 있어요."}
            </p>
            {!care && star.body.trim().length >= MIN_FLOAT_LENGTH && <div className={styles.floatRow}><FloatButton id={star.id} free={me.free_star_today > 0} coins={me.coins} /></div>}
            <p className="caption faint">
              {!care && star.body.trim().length < MIN_FLOAT_LENGTH ? `별빛은 ${MIN_FLOAT_LENGTH}자부터 받을 수 있어요. 글을 조금 더 써 보세요. · ` : ""}
              {me.free_star_today > 0 ? "오늘 무료 별빛 받기가 1번 남았어요. 이후 한 번에 5코인이에요." : "오늘 무료 별빛 받기를 썼어요. 한 번에 5코인이에요."}
            </p>
          </section>
        )}
      </aside>
      {sp.stopped === "1" && <Toast title="별빛 받기를 그만뒀어요" sub="무료와 코인은 그대로예요" />}
      {sp.kept === "1" && <><StarBirth id={star.id} unlit={mood.color} /><Toast title="별빛 없이 띄웠어요" />{completed}</>}
    </div>
  );
}

const SHARP: Record<string, string> = { soft: "둥근", normal: "보통 뾰족함", sharp: "아주 뾰족함" };

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

// Figma 웹 v1.1 · 별이 떴어요 (640:31510): the new star, its starlight and moods on the left; what to do next
// and the open 별빛 풀이 on the right. Sections come in 0.2 s apart, then the reading's lines (기획서 17.4).
function Result({ star, slot }: { star: Star; slot: { name: string; filled: number; total: number } | null }) {
  const a = star.analysis!;
  const at = (i: number) => ({ ["--i" as string]: i });
  const shape = a.shape ?? star.shape ?? null;
  const color = moodOf(star.mood).color;
  return (
    <div className={styles.born11}>
      <section className={styles.bornStar} style={at(0)} data-rise>
        <div className={styles.bornHero} aria-hidden="true">
          <span className="v2-glow" style={{ ["--c" as string]: color, inset: "-30% -10%" }} />
          <StarGlyph points={shape?.points} sharpness={shape?.sharpness} mood={star.mood} size={200} twinkle />
        </div>
        <p className={styles.bornLight}><b>{a.starlight}</b><span>별빛</span></p>
        <p className={styles.bornQuote}>“{a.observation}”</p>
        <div className={styles.moodChips}>
          {a.moods.map((m) => <span key={m.mood} className={styles.moodChip} style={{ ["--c" as string]: moodOf(m.mood).color }}>{moodOf(m.mood).label}</span>)}
        </div>
      </section>
      <section className={styles.bornSide}>
        <p className="caption faint" style={at(1)} data-rise>{fullDate(star.created_at)} · {star.title || "제목 없는 별"}</p>
        <h1 className={styles.bornTitle} style={at(2)} data-rise>별이 떠올랐어요</h1>
        <p className="body-l muted" style={at(3)} data-rise>
          {slot ? `오늘의 별이 ${slot.name}자리의 ${slot.filled}번째 자리를 채웠어요.${slot.total > slot.filled ? ` 남은 자리는 ${slot.total - slot.filled}개예요.` : ""}`
            : "오늘의 별이 이번 달 별자리의 빈 자리를 채웠어요."}
        </p>
        <div className={styles.bornActions} style={at(4)} data-rise>
          <Link href="/constellation" className="btn btn-primary">나의 별자리 보기</Link>
          <Link href={`/stars/${star.id}`} className="btn btn-secondary">우주 광장에 나누기</Link>
          <Link href="/records" className={styles.bornLink}>기록으로</Link>
        </div>
        <div className={styles.bornReading}>
          <StarlightReading analysis={a} readAt={star.created_at} version={star.prism_version} open animate />
        </div>
      </section>
    </div>
  );
}
