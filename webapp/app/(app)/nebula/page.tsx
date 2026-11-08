import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { ChevronRight, Nebula as NebulaIcon } from "@/components/icons";
import { NebulaFigure } from "@/components/NebulaFigure";
import { api } from "@/lib/api";
import { MIN_STARS, SILHOUETTES, type Dot } from "@/lib/nebula";
import type { Growth, Nebula, NebulaSummary, StarSummary } from "@/lib/types";
import styles from "./nebula.module.css";

export const metadata: Metadata = { title: "나의 성운" };

const NEED: Record<string, string> = { stars: "별", deep: "깊은 별", supernova: "초신성", nebulae: "성운", floated: "띄운 별" };

type Beside = { share_id: string; name: string; depth_level: number };

// Figma W-41 (나의 성운 · 그린 성운) and W-42 (아직 그리기 전), after W-16.
export default function NebulaPage() {
  return (
    <Suspense fallback={<><h1 className="h1">나의 성운</h1><div className={`card ${styles.loading}`} aria-busy="true" /></>}>
      <Mine />
    </Suspense>
  );
}

async function Mine() {
  const [list, growth] = await Promise.all([
    api<{ mine: NebulaSummary[]; beside: Beside[] }>("/v1/nebulae"),
    api<Growth>("/v1/growth"),
  ]);
  // The canvas shows the nebula drawn or reshaped most recently.
  const recent = [...list.mine].sort((a, b) => (b.updated_at ?? b.created_at).localeCompare(a.updated_at ?? a.created_at))[0];
  const [latest, floated] = await Promise.all([
    recent ? api<Nebula>(`/v1/nebulae/${recent.id}`) : null,
    recent ? null : api<{ items: StarSummary[] }>("/v1/stars?state=floated&limit=40"),
  ]);
  const canDraw = growth.floated >= MIN_STARS;
  const needs = growth.next ? Object.entries(growth.next.needs) : [];
  const stage = growth.stage_name ?? "첫 걸음 전";
  return (
    <>
      <header className={styles.header}>
        <div>
          <h1 className="h1">나의 성운</h1>
          <p className="body-m" style={{ color: "var(--gold)" }}>
            {latest ? [latest.name, latest.silhouette ? SILHOUETTES[latest.silhouette]?.name : null, stage].filter(Boolean).join(" · ") : `아직 이름 없는 성운 · ${stage}`}
          </p>
        </div>
        {latest && canDraw && <Link href="/nebula/new" className="btn btn-secondary">새 성운 그리기</Link>}
      </header>
      <div className={styles.body}>
        <section className={`card ${styles.hero}`}>
          {latest && <Link href={`/nebula/${latest.id}/edit`} className={styles.chip}>모양 바꾸기</Link>}
          {latest ? (
            <Link href={`/nebula/${latest.id}`} className={styles.figure} aria-label={`${latest.name} 자세히 보기`}>
              <NebulaFigure width={560} height={520} label={latest.name}
                figure={{ silhouette: latest.silhouette, edges: latest.edges, dots: [...[...latest.stars].sort((a, b) => a.index - b.index).map((s): Dot => ({ mood: s.mood })), ...latest.guests.map((): Dot => ({ guest: true }))] }} />
            </Link>
          ) : (
            <div className={styles.empty}>
              <div className={styles.scatter}>
                <NebulaFigure width={560} height={380} label={`띄운 별 ${growth.floated}개`}
                  figure={{ silhouette: null, edges: [], dots: (floated?.items ?? []).map((s): Dot => ({ mood: s.mood })) }} />
              </div>
              <p className="body-m muted">띄운 별 {growth.floated}개가 떠 있어요. 별을 {MIN_STARS}개 이상 골라 이으면 나만의 성운이 돼요.</p>
              {canDraw ? <Link href="/nebula/new" className="btn btn-primary">성운 그리기</Link>
                : <span className="caption faint">별을 {MIN_STARS - growth.floated}개 더 띄우면 그릴 수 있어요</span>}
            </div>
          )}
        </section>
        <aside className={styles.side}>
          <div className={styles.stats}>
            {[["떠 있는 별", growth.floated], ["깊은 별", growth.deep], ["초신성", growth.supernova]].map(([l, v]) => (
              <div key={l} className={`card ${styles.stat}`}><span className="h1">{v}</span><span className="caption muted">{l}</span></div>
            ))}
          </div>
          {growth.next && (
            <div className={`card ${styles.growth}`}>
              <div className={styles.growthHead}><span className="label-m">{growth.next.stage_name}</span><span className="caption faint">{growth.stage_name ?? "첫 걸음 전"} → 다음 걸음</span></div>
              {needs.map(([k, [now, goal]]) => (
                <div key={k} className={styles.need}>
                  <span className="caption muted">{NEED[k] ?? k} {now} / {goal}</span>
                  <i style={{ ["--v" as string]: `${Math.min(100, (now / goal) * 100)}%` }} />
                </div>
              ))}
              <p className="body-s muted">서두르지 않아도 괜찮아요.</p>
            </div>
          )}
          <div className={styles.actions}>
            <Link href="/plaza" className="btn btn-secondary">우주 광장</Link>
            {latest && <Link href={`/nebula/${latest.id}`} className="btn btn-primary">자세히 보기</Link>}
          </div>
          {(list.mine.length > 0 || list.beside.length > 0) && (
            <div className={styles.collection}>
              <span className="caption faint">성운 모음</span>
              {list.mine.map((n) => <Row key={n.id} n={n} href={`/nebula/${n.id}`} note="내가 그린" />)}
              {list.beside.map((n) => (
                <Link key={n.share_id} href={`/plaza/nebulae/${n.share_id}`} className={styles.row} prefetch={false}>
                  <NebulaIcon size={18} />
                  <span className={styles.rowText}><span className="label-m">{n.name}</span><span className="caption faint">곁에 둔 성운 · 깊이 {n.depth_level}</span></span>
                  <ChevronRight size={16} />
                </Link>
              ))}
            </div>
          )}
        </aside>
      </div>
    </>
  );
}

function Row({ n, href, note }: { n: NebulaSummary; href: string; note: string }) {
  return (
    <Link href={href} className={styles.row} prefetch={false}>
      <NebulaIcon size={18} />
      <span className={styles.rowText}>
        <span className="label-m">{n.name}</span>
        <span className="caption faint">{note} · 별 {n.star_count}개{n.silhouette ? ` · ${SILHOUETTES[n.silhouette]?.name ?? ""}` : ""}{n.shared ? " · 하늘에 띄움" : ""}</span>
      </span>
      <ChevronRight size={16} />
    </Link>
  );
}
