import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft, Heart, StarFilled, Telescope } from "@/components/icons";
import { StarCard } from "@/components/StarCard";
import { StarlightReading } from "@/components/StarlightReading";
import { api, ApiError } from "@/lib/api";
import { longDate, moodOf, dateTime } from "@/lib/format";
import type { Star } from "@/lib/types";
import { ShareStar } from "./ShareStar";
import { DeleteButton, FloatButton } from "./StarActions";
import styles from "./star.module.css";

export const metadata: Metadata = { title: "별 상세" };

// Figma W-12 (별빛 받은 별), W-32 (별빛 없는 별), W-24 (별이 떠올랐어요, ?new=1), W-36 (마음 돌봄, ?care=1).
export default function StarPage({ params, searchParams }: PageProps<"/stars/[id]">) {
  return (
    <>
      <Link href="/" className={styles.back}><ChevronLeft size={18} />나의 밤하늘</Link>
      <Suspense fallback={<div className={`card ${styles.loading}`} aria-busy="true" />}>
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
  const floated = star.state === "floated" && star.analysis;
  const justFloated = sp.new === "1" && floated;
  const care = sp.care === "1";
  const mood = moodOf(star.mood);
  if (justFloated) return <Result star={star} />;
  return (
    <div className={styles.body}>
      <article className={styles.article}>
        {justFloated && <p className={styles.born}><StarFilled size={16} />별이 떠올랐어요</p>}
        <p className="caption faint">{longDate(star.created_at)} · {dateTime(star.created_at).split(" · ")[1]}</p>
        <h1 className="display">{star.title || "제목 없는 별"}</h1>
        <div className={styles.meta}>
          <span className={styles.mood} style={{ ["--c" as string]: mood.color }}>{mood.label}</span>
          {!floated && <span className="label-s muted">{star.analysis_failed ? "별빛을 읽지 못한 별 · 다시 받을 수 있어요" : "별빛 없는 별"}</span>}
        </div>
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
            <Link href="/write" className="btn btn-primary btn-block">별 잇기</Link>
            <ShareStar id={star.id} title={star.title || "제목 없는 별"} body={star.body} shared={star.shared} />
          </>
        ) : (
          <div className={`card ${styles.keptCard}`}>
            <span className="label-m">{star.analysis_failed ? "별빛을 읽지 못했어요" : "별빛을 받아 볼까요?"}</span>
            <p className="body-s muted">
              {star.analysis_failed ? "코인은 차감되지 않았어요. 다시 받으면 별빛 프리즘이 한 번 더 읽어요." : "별빛 없이 띄운 별이에요. 별빛을 받으면 별빛 프리즘이 마음의 결을 읽어요. 받은 뒤에는 글이 잠겨요."}
            </p>
            {!care && <FloatButton id={star.id} />}
          </div>
        )}
        <div className={styles.more}>
          <DeleteButton id={star.id} title={star.title || "제목 없는 별"} />
        </div>
      </aside>
    </div>
  );
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
        {a.telescope_teaser && (
          <div className={`card ${styles.offer}`} style={at(4)} data-rise>
            <span className={styles.offerHead}><Telescope size={16} />마음 망원경</span>
            <p className="observation">{a.telescope_teaser}</p>
            <p className="caption faint">숨은 마음의 결을 더 들여다볼 수 있어요.</p>
          </div>
        )}
        <div className={styles.resultActions} style={at(5)} data-rise>
          <Link href={`/stars/${star.id}`} className="btn btn-secondary">마음 망원경 켜기</Link>
          <Link href="/constellation" className="btn btn-primary">나의 별자리 보기</Link>
        </div>
        <Link href={`/stars/${star.id}`} className={styles.shareLink} style={at(6)} data-rise>우주 광장에 나누기</Link>
        <StarlightReading analysis={a} readAt={star.created_at} version={star.prism_version} open animate />
      </div>
    </div>
  );
}
