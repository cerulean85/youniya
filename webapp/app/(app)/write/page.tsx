import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Close } from "@/components/icons";
import { api } from "@/lib/api";
import type { Draft, Me, Star } from "@/lib/types";
import { WriteForm, type Source } from "./WriteForm";
import styles from "./write.module.css";

export const metadata: Metadata = { title: "별 만들기" };

// Figma W-11 (별 만들기) with W-23 (분석 중) while a star is made; ?rewrite= is 고쳐 쓰기 (W-73, W-46),
// ?link= is 별 잇기 · 새 별 쓰기 (W-39).
export default function WritePage({ searchParams }: PageProps<"/write">) {
  return (
    <Suspense fallback={<div className={`card ${styles.loading}`} aria-busy="true" />}>
      <Editor searchParams={searchParams} />
    </Suspense>
  );
}

async function Editor({ searchParams }: Pick<PageProps<"/write">, "searchParams">) {
  const sp = await searchParams;
  const pick = (v: string | string[] | undefined) => (typeof v === "string" && /^[\w-]{8,64}$/.test(v) ? v : null);
  const rewrite = pick(sp.rewrite), link = rewrite ? null : pick(sp.link);
  const [draft, me, star] = await Promise.all([
    api<Draft>("/v1/drafts/current"), api<Me>("/v1/me"),
    rewrite || link ? api<Star>(`/v1/stars/${rewrite ?? link}`).catch(() => null) : null,
  ]);
  const source: Source | null = star && {
    kind: rewrite ? "rewrite" : "link", id: star.id, title: star.title || "제목 없는 별",
    question: star.analysis?.rewrite_question ?? null, moods: star.moods ?? [star.mood], body: star.body,
  };
  // One draft per person: a 고쳐 쓰기 draft belongs to its star, every other draft to plain writing.
  const own = draft && (source?.kind === "rewrite" ? draft.source_star_id === source.id : !draft.source_star_id) ? draft : null;
  const back = source ? `/stars/${source.id}` : "/";
  return (
    <>
      {source?.kind !== "rewrite" && <div className={styles.top}>
        <Link href={back} className={styles.close} data-leave><Close size={18} />닫기</Link>
        <span className="label-m">{source ? "별 잇기 · 새 별 쓰기" : "별 만들기"}</span>
        <span className={styles.spacer} />
      </div>}
      <WriteForm key={source ? `${source.kind}-${source.id}` : "new"} draft={own} source={source}
        freeStarToday={me.free_star_today} coins={me.coins} />
    </>
  );
}
