import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { NebulaFigure } from "@/components/NebulaFigure";
import { StarGlyph } from "@/components/StarGlyph";
import { Heart } from "@/components/icons";
import { api } from "@/lib/api";
import type { Dot } from "@/lib/nebula";
import type { PlazaNebula, PlazaStar } from "@/lib/types";
import styles from "./plaza.module.css";

export const metadata: Metadata = { title: "우주 광장" };

// Figma W-13. Only the one sentence each person chose is here, with no name or account.
export default function PlazaPage({ searchParams }: PageProps<"/plaza">) {
  return (
    <>
      <header className={styles.header}>
        <h1 className="h1">우주 광장</h1>
        <p className="body-m muted">누군가의 별이에요. 눌러서 한 문장을 읽고, 마음이 닿으면 공명을 남겨 보세요.</p>
      </header>
      <Suspense fallback={<div className={`card ${styles.loading}`} aria-busy="true" />}>
        <Plaza searchParams={searchParams} />
      </Suspense>
    </>
  );
}

async function Plaza({ searchParams }: Pick<PageProps<"/plaza">, "searchParams">) {
  const sp = await searchParams;
  const tab = sp.tab === "nebula" ? "nebula" : "star";
  const sort = sp.sort === "similar" ? "similar" : "new";
  const filter = sp.filter === "new" || sp.filter === "beside" ? sp.filter : "similar";
  const notice = sp.reported ? "신고를 받았어요. 그 별은 이제 보이지 않아요." : sp.blocked ? "차단했어요. 서로의 별이 더 이상 보이지 않아요." : null;
  return (
    <>
      {notice && <p className={styles.notice} role="status">{notice}</p>}
      <div className={styles.controls}>
        <nav className={styles.segment} aria-label="광장 종류">
          <Link href="/plaza" aria-current={tab === "star" ? "page" : undefined}>별</Link>
          <Link href="/plaza?tab=nebula" aria-current={tab === "nebula" ? "page" : undefined}>성운</Link>
        </nav>
        <span className={styles.spacer} />
        {tab === "nebula" && (
          <nav className={styles.sorts} aria-label="거르기">
            <Link href="/plaza?tab=nebula" aria-current={filter === "similar" ? "true" : undefined}>나와 비슷한 결</Link>
            <Link href="/plaza?tab=nebula&filter=new" aria-current={filter === "new" ? "true" : undefined}>새로 띄운 성운</Link>
            <Link href="/plaza?tab=nebula&filter=beside" aria-current={filter === "beside" ? "true" : undefined}>곁에 둔 성운</Link>
          </nav>
        )}
        {tab === "star" && (
          <nav className={styles.sorts} aria-label="정렬">
            <Link href="/plaza" aria-current={sort === "new" ? "true" : undefined}>새로 뜬 것</Link>
            <Link href="/plaza?sort=similar" aria-current={sort === "similar" ? "true" : undefined}>나와 결이 비슷한</Link>
          </nav>
        )}
      </div>
      {tab === "star" ? <Stars sort={sort} /> : <Nebulae filter={filter} />}
    </>
  );
}

async function Stars({ sort }: { sort: string }) {
  const { items } = await api<{ items: PlazaStar[] }>(`/v1/plaza/stars?sort=${sort}&limit=40`);
  if (items.length === 0) {
    return (
      <div className={`card ${styles.empty}`}>
        <p className="h3">아직 광장에 뜬 별이 없어요</p>
        <p className="body-m muted">별 상세에서 한 문장을 골라 가장 먼저 나눠 보세요.</p>
      </div>
    );
  }
  return (
    <div className={styles.grid}>
      {items.map((s) => (
        <Link key={s.id} href={`/plaza/stars/${s.id}`} className={`card ${styles.card}`} prefetch={false}>
          <div className={styles.sky}><StarGlyph points={s.shape?.points} sharpness={s.shape?.sharpness} mood={s.mood} size={64} /></div>
          <span className="label-m">{s.name}</span>
          <span className={`body-s muted ${styles.quote}`}>{s.quote}</span>
          <span className={styles.foot} data-on={s.resonated}><Heart size={14} />{s.resonated ? "공명했어요" : "공명"}</span>
        </Link>
      ))}
    </div>
  );
}

async function Nebulae({ filter }: { filter: string }) {
  const { items } = await api<{ items: PlazaNebula[] }>(`/v1/plaza/nebulae?filter=${filter}&limit=40`);
  if (items.length === 0) {
    return (
      <div className={`card ${styles.empty}`}>
        <p className="h3">{filter === "beside" ? "아직 곁에 둔 성운이 없어요" : "아직 하늘에 뜬 성운이 없어요"}</p>
        <p className="body-m muted">{filter === "beside" ? "마음이 닿은 성운을 곁에 두면 이곳에 모여요." : "나의 성운에서 하늘에 띄우면 이곳에 떠올라요."}</p>
      </div>
    );
  }
  return (
    <div className={styles.grid}>
      {items.map((n) => (
        <Link key={n.id} href={`/plaza/nebulae/${n.id}`} className={`card ${styles.card}`} prefetch={false}>
          <div className={styles.sky}>
            <NebulaFigure width={240} height={128} compact label={n.name}
              figure={{ silhouette: n.shape.silhouette, edges: n.shape.edges, dots: n.shape.stars.map((s): Dot => ({ mood: s.mood })) }} />
          </div>
          <span className="label-m">{n.name}</span>
          <span className={`body-s muted ${styles.quote}`}>{n.quote ?? `별 ${n.shape.stars.length}개 · 깊이 ${n.depth_level}`}</span>
          <span className={styles.foot} data-on={n.resonated}><Heart size={14} />{n.resonated ? "공명했어요" : "공명"}</span>
        </Link>
      ))}
    </div>
  );
}
