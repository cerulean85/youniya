import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft, StarFilled } from "@/components/icons";
import { NebulaFigure } from "@/components/NebulaFigure";
import { api, ApiError } from "@/lib/api";
import { dateTime, moodOf } from "@/lib/format";
import { SILHOUETTES, type Dot } from "@/lib/nebula";
import type { Me, Nebula, Story } from "@/lib/types";
import { PolishButton, ShareNebula } from "./NebulaActions";
import styles from "./nebula-detail.module.css";

export const metadata: Metadata = { title: "성운" };

// Figma 70 (나의 성운 상세) and 83 (성운 이야기), on one desktop page.
export default function NebulaDetailPage({ params, searchParams }: PageProps<"/nebula/[id]">) {
  return (
    <>
      <Link href="/nebula" className={styles.back}><ChevronLeft size={18} />나의 성운</Link>
      <Suspense fallback={<div className={`card ${styles.loading}`} aria-busy="true" />}>
        <Detail params={params} searchParams={searchParams} />
      </Suspense>
    </>
  );
}

async function Detail({ params, searchParams }: Pick<PageProps<"/nebula/[id]">, "params" | "searchParams">) {
  const [{ id }, sp] = await Promise.all([params, searchParams]);
  let n: Nebula, story: Story, me: Me;
  try {
    [n, story, me] = await Promise.all([api<Nebula>(`/v1/nebulae/${id}`), api<Story>(`/v1/nebulae/${id}/story`), api<Me>("/v1/me")]);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  const stars = [...n.stars].sort((a, b) => a.index - b.index);
  return (
    <div className={styles.body}>
      <section className={styles.main}>
        {sp.new === "1" && <p className={styles.born}><StarFilled size={16} />성운을 그렸어요</p>}
        {sp.changed === "1" && <p className={styles.born} role="status"><StarFilled size={16} />모양을 바꿨어요{sp.plaza === "1" ? " · 광장의 성운도 새 모양으로 바뀌었어요" : ""}</p>}
        <h1 className="display">{n.name}</h1>
        <p className="body-m muted">{n.silhouette ? `${SILHOUETTES[n.silhouette]?.name ?? n.silhouette} 모양` : "직접 그린 모양"} · 별 {n.star_count}개{n.guests.length ? ` · 손님별 ${n.guests.length}개` : ""} · 깊이 {n.depth_level}</p>
        <div className={`card ${styles.figure}`}>
          <Link href={`/nebula/${n.id}/edit`} className={styles.chip}>모양 바꾸기</Link>
          <NebulaFigure width={640} height={460} label={n.name}
            figure={{ silhouette: n.silhouette, edges: n.edges, dots: [...stars.map((s): Dot => ({ mood: s.mood })), ...n.guests.map((): Dot => ({ guest: true }))] }} />
        </div>
        <section className={`card ${styles.story}`} aria-labelledby="story">
          <div className={styles.storyHead}>
            <h2 id="story" className="h3">성운 이야기</h2>
            {!story.polished && <PolishButton id={n.id} free={story.polish_free} cost={story.polish_cost} coins={me.coins} />}
          </div>
          <p className="caption faint">별마다 마음이 가장 또렷한 한 문장을 시간 순서로 엮었어요. 문장은 바꾸지 않아요.</p>
          <ol className={styles.entries}>
            {story.entries.map((e, i) => (
              <li key={e.star_id}>
                <span className="caption faint">{dateTime(e.date)} · {e.title || "제목 없는 별"}</span>
                <p className="journal">{e.sentence}</p>
                {story.bridges?.[i] && i < story.entries.length - 1 && <p className={styles.bridge}>✦ {story.bridges[i]}</p>}
              </li>
            ))}
          </ol>
        </section>
      </section>
      <aside className={styles.side}>
        <ShareNebula id={n.id} shared={n.shared} />
        <div className={styles.stars}>
          <span className="caption faint">이 성운의 별</span>
          {stars.map((s) => (
            <Link key={s.id} href={`/stars/${s.id}`} className={styles.star} prefetch={false}>
              <span className={styles.dot} style={{ background: moodOf(s.mood).color }} />
              <span className={styles.starText}><span className="label-m">{s.title || "제목 없는 별"}</span><span className="caption faint">{dateTime(s.created_at)}</span></span>
              <span className="label-s muted">{s.starlight} 별빛</span>
            </Link>
          ))}
        </div>
      </aside>
    </div>
  );
}
