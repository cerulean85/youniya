import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
import { NebulaFigure } from "@/components/NebulaFigure";
import { api, ApiError } from "@/lib/api";
import { SILHOUETTES, type Dot } from "@/lib/nebula";
import type { PlazaNebula } from "@/lib/types";
import { PlazaActions } from "../../stars/[id]/PlazaActions";
import { Lines } from "./Lines";
import styles from "../../stars/[id]/plaza-star.module.css";

export const metadata: Metadata = { title: "다른 이의 성운" };

type LineList = { items: { id: string; text: string; created_at: string; mine: boolean }[]; can_leave: boolean; max_length: number };

// Figma 73 (다른 이의 성운) and 74 (별빛 한 줄).
export default function PlazaNebulaPage({ params }: PageProps<"/plaza/nebulae/[id]">) {
  return (
    <>
      <Link href="/plaza" className={styles.back}><ChevronLeft size={18} />우주 광장</Link>
      <Suspense fallback={<div className={`card ${styles.card}`} aria-busy="true" style={{ minHeight: 520 }} />}>
        <Detail params={params} />
      </Suspense>
    </>
  );
}

async function Detail({ params }: Pick<PageProps<"/plaza/nebulae/[id]">, "params">) {
  const { id } = await params;
  let n: PlazaNebula, lines: LineList;
  try {
    [n, lines] = await Promise.all([api<PlazaNebula>(`/v1/plaza/nebulae/${id}`), api<LineList>(`/v1/plaza/nebulae/${id}/lines`)]);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  return (
    <article className={`card ${styles.card}`} style={{ maxWidth: 640 }}>
      <header className={styles.head}>
        <h1 className="h2">{n.name}</h1>
        <div className={styles.tags}>
          <span className={styles.tag}>익명의 별지기</span>
          <span className={styles.tag}>{n.shape.silhouette ? `${SILHOUETTES[n.shape.silhouette]?.name ?? ""} 모양` : "직접 그린 모양"} · 별 {n.shape.stars.length}개</span>
          <span className={`${styles.tag} ${styles.gold}`}>깊이 {n.depth_level}</span>
        </div>
      </header>
      <div style={{ aspectRatio: "560 / 360" }}>
        <NebulaFigure width={560} height={360} label={n.name}
          figure={{ silhouette: n.shape.silhouette, edges: n.shape.edges, dots: n.shape.stars.map((s): Dot => ({ mood: s.mood })) }} />
      </div>
      {n.quote && <blockquote className={styles.quote}><p className="observation">“{n.quote}”</p></blockquote>}
      <PlazaActions kind="nebula" id={n.id} resonated={n.resonated} beside={n.beside} />
      <Lines shareId={n.id} open={n.receive_lines} {...lines} />
    </article>
  );
}
