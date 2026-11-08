import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { StarGlyph } from "@/components/StarGlyph";
import { Heart } from "@/components/icons";
import { api } from "@/lib/api";
import type { PlazaStar } from "@/lib/types";
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
        {tab === "star" && (
          <nav className={styles.sorts} aria-label="정렬">
            <Link href="/plaza" aria-current={sort === "new" ? "true" : undefined}>새로 뜬 것</Link>
            <Link href="/plaza?sort=similar" aria-current={sort === "similar" ? "true" : undefined}>나와 결이 비슷한</Link>
          </nav>
        )}
      </div>
      {tab === "star" ? <Stars sort={sort} /> : (
        <div className={`card ${styles.empty}`}>
          <p className="h3">성운 광장은 곧 열려요</p>
          <p className="body-m muted">성운 화면을 만들 때 함께 열어요. 지금은 별 광장을 둘러봐 주세요.</p>
        </div>
      )}
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
