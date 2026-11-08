import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { StarGlyph } from "@/components/StarGlyph";
import { api } from "@/lib/api";
import type { PlazaNebula, PlazaStar } from "@/lib/types";
import { NebulaField } from "./NebulaField";
import styles from "./plaza.module.css";

export const metadata: Metadata = { title: "우주 광장" };

const FILTERS = [
  { key: "new", label: "새로 뜬 것" },
  { key: "similar", label: "나와 결이 비슷한" },
  { key: "beside", label: "곁에 둔 것" },
] as const;
type Filter = (typeof FILTERS)[number]["key"];

// Figma W-44 (09-2 우주 광장 · 합친 화면): one filter for both the nebula field and the star list.
// Only the sentence each person chose is shown; no names, accounts, ranks or counts.
export default function PlazaPage({ searchParams }: PageProps<"/plaza">) {
  return (
    <>
      <header className={styles.header}>
        <h1 className="h1">우주 광장</h1>
        <p className="body-m muted">모인 성운의 모양을 둘러보고, 별이 남긴 한 문장을 읽어 보세요. 순위나 인기는 없어요.</p>
      </header>
      <Suspense fallback={<div className={`card ${styles.loading}`} aria-busy="true" />}>
        <Plaza searchParams={searchParams} />
      </Suspense>
    </>
  );
}

async function Plaza({ searchParams }: Pick<PageProps<"/plaza">, "searchParams">) {
  const sp = await searchParams;
  const filter: Filter = FILTERS.some((f) => f.key === sp.filter) ? (sp.filter as Filter) : "new";
  const [tonight, nebulae, stars] = await Promise.all([
    api<{ count: number; mine: number }>("/v1/plaza/tonight"),
    api<{ items: PlazaNebula[] }>(`/v1/plaza/nebulae?filter=${filter}&limit=24`),
    api<{ items: PlazaStar[] }>(`/v1/plaza/stars?sort=${filter}&limit=40`),
  ]);
  const notice = sp.reported ? "신고를 받았어요. 이제 보이지 않아요." : sp.blocked ? "차단했어요. 서로의 별과 성운이 더 이상 보이지 않아요." : null;
  return (
    <>
      {notice && <p className={styles.notice} role="status">{notice}</p>}
      {tonight.count > 0 && (
        <p className={styles.tonight}>
          오늘 밤, <b>{tonight.count.toLocaleString("ko-KR")}개</b>의 마음이 모였어요{tonight.mine > 0 && <> · 내 별 <b>{tonight.mine}개</b>도 함께 빛나요</>}
        </p>
      )}
      <nav className={styles.sorts} aria-label="거르기">
        {FILTERS.map((f) => (
          <Link key={f.key} href={f.key === "new" ? "/plaza" : `/plaza?filter=${f.key}`} aria-current={filter === f.key ? "true" : undefined}>{f.label}</Link>
        ))}
      </nav>
      <div className={styles.body}>
        <section className={styles.field} aria-label="성운 들판">
          {nebulae.items.length ? <NebulaField nebulae={nebulae.items} /> : (
            <div className={styles.fieldEmpty}>
              <p className="h3">{filter === "beside" ? "아직 곁에 둔 성운이 없어요" : "아직 하늘에 뜬 성운이 없어요"}</p>
              <p className="body-m muted">{filter === "beside" ? "마음이 닿은 성운을 곁에 두면 이곳에 모여요." : "나의 성운에서 하늘에 띄우면 이곳에 떠올라요."}</p>
            </div>
          )}
        </section>
        <section className={styles.records} aria-labelledby="records-title">
          <h2 id="records-title" className="h2">별 기록</h2>
          <p className="body-s muted">누군가 골라 나눈 한 문장이에요. 눌러서 읽고, 마음이 닿으면 공명을 남겨 보세요.</p>
          <StarList stars={stars.items} filter={filter} />
        </section>
      </div>
    </>
  );
}

async function StarList({ stars, filter }: { stars: PlazaStar[]; filter: Filter }) {
  if (stars.length === 0) return <p className={`body-s faint ${styles.listEmpty}`}>{filter === "beside" ? "아직 곁에 둔 별이 없어요." : "아직 광장에 뜬 별이 없어요."}</p>;
  await connection(); // "12분 전" is relative to the request
  const rows = withAgo(stars);
  return (
    <ul className={styles.list}>
      {rows.map(({ star: s, ago }) => (
        <li key={s.id}>
          <Link href={`/plaza/stars/${s.id}`} className={styles.row} prefetch={false}>
            <span className={styles.thumb}><StarGlyph points={s.shape?.points} sharpness={s.shape?.sharpness} mood={s.mood} size={24} /></span>
            <span className={styles.rowText}>
              <span className="observation">“{s.quote}”</span>
              <span className="caption faint">{s.name} · {ago}</span>
            </span>
            <span className={styles.res} data-on={s.resonated} aria-label={s.resonated ? "공명했어요" : "공명 전"}>✦</span>
          </Link>
        </li>
      ))}
    </ul>
  );
}

/** Each star with "방금" / "12분 전" / "1시간 전" / "2일 전", from one reading of the clock. */
function withAgo(stars: PlazaStar[]) {
  const now = Date.now();
  return stars.map((star) => ({ star, ago: ago(star.created_at, now) }));
}

function ago(iso: string, now: number) {
  const m = Math.max(0, Math.round((now - new Date(iso).getTime()) / 60000));
  if (m < 1) return "방금";
  if (m < 60) return `${m}분 전`;
  if (m < 60 * 24) return `${Math.floor(m / 60)}시간 전`;
  return `${Math.floor(m / 60 / 24)}일 전`;
}
