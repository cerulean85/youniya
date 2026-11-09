import type { Metadata } from "next";
import { PlazaSkeleton } from "@/components/Skeleton";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ChevronRight } from "@/components/icons";
import { PlazaRow } from "@/components/PlazaRow";
import { RestrictedBanner } from "@/components/Restricted";
import { api } from "@/lib/api";
import { requireNickname, withAgo } from "@/lib/plaza";
import type { MyShare, PlazaStar } from "@/lib/types";
import styles from "./plaza.module.css";

export const metadata: Metadata = { title: "우주 광장" };

const FILTERS = [
  { key: "new", label: "새로 뜬 것" },
  { key: "similar", label: "나와 결이 비슷한" },
  { key: "beside", label: "곁에 둔 것" },
] as const;
type Filter = (typeof FILTERS)[number]["key"];

// Figma W-44 (기획서 15.2 · 17.2): one list of shared stars with their 별지기 이름; stars without starlight
// sit below. No resonance counts for anyone else's star.
export default function PlazaPage({ searchParams }: PageProps<"/plaza">) {
  return (
    <>
      <header className={styles.header}>
        <h1 className="h1">우주 광장</h1>
        <p className="body-m muted">별지기들이 나눈 별이에요. 눌러서 글을 읽고, 마음이 닿으면 공명을 남겨 보세요.</p>
      </header>
      <Suspense fallback={<PlazaSkeleton />}>
        <Plaza searchParams={searchParams} />
      </Suspense>
    </>
  );
}

async function Plaza({ searchParams }: Pick<PageProps<"/plaza">, "searchParams">) {
  const sp = await searchParams;
  const filter: Filter = FILTERS.some((f) => f.key === sp.filter) ? (sp.filter as Filter) : "new";
  const me = await requireNickname(filter === "new" ? "/plaza" : `/plaza?filter=${filter}`);
  const [tonight, stars, mine, beside] = await Promise.all([
    api<{ count: number; mine: number }>("/v1/plaza/tonight"),
    api<{ items: PlazaStar[] }>(`/v1/plaza/stars?sort=${filter}&limit=60`),
    api<{ stars: MyShare[] }>("/v1/me/shares"),
    filter === "beside" ? null : api<{ items: PlazaStar[] }>("/v1/plaza/stars?sort=beside&limit=100"),
  ]);
  await connection(); // "12분 전" is relative to the request
  // Lit stars first, then the ones without starlight (17.2), each in the server's order.
  const rows = withAgo([...stars.items.filter((s) => s.has_starlight), ...stars.items.filter((s) => !s.has_starlight)]);
  const besideCount = (beside ?? stars).items.length;
  const lines = mine.stars.reduce((n, s) => n + (s.lines ?? 0), 0);
  const notice = sp.reported ? "신고를 받았어요. 이제 보이지 않아요." : sp.blocked ? "차단했어요. 서로의 별과 별빛 한 줄이 더 이상 보이지 않아요." : null;
  return (
    <>
      {notice && <p className={styles.notice} role="status">{notice}</p>}
      {tonight.count > 0 && (
        <p className={styles.tonight}>
          오늘 밤, <b>{tonight.count.toLocaleString("ko-KR")}개</b>의 마음이 모였어요{tonight.mine > 0 && <> · 내 별 <b>{tonight.mine}개</b>도 함께 빛나요</>}
        </p>
      )}
      {me.plaza_restricted_until && new Date(me.plaza_restricted_until) > new Date() && <RestrictedBanner until={me.plaza_restricted_until} open={sp.restricted === "1"} />}
      <nav className={styles.sorts} aria-label="거르기">
        {FILTERS.map((f) => (
          <Link key={f.key} href={f.key === "new" ? "/plaza" : `/plaza?filter=${f.key}`} aria-current={filter === f.key ? "true" : undefined}>{f.label}</Link>
        ))}
      </nav>
      <div className={styles.body}>
        <section className={styles.records} aria-label="나눈 별">
          {rows.length === 0 ? (
            <p className={`body-m faint ${styles.listEmpty}`}>
              {filter === "beside" ? "아직 곁에 둔 별이 없어요. 공명하거나 곁에 두면 이곳에 모여요." : filter === "similar" ? "나와 결이 비슷한 별이 아직 없어요." : "아직 광장에 뜬 별이 없어요."}
            </p>
          ) : (
            <ul className={styles.list}>
              {rows.map(({ star, ago }) => <li key={star.id}><PlazaRow star={star} ago={ago} /></li>)}
            </ul>
          )}
        </section>
        <aside className={styles.side}>
          <div className={`card ${styles.mine}`}>
            <span className="label-m">내 별</span>
            <Link href={`/plaza/keepers/${encodeURIComponent(me.nickname!)}`}><span>내가 나눈 별</span><span>{mine.stars.length}개<ChevronRight size={14} /></span></Link>
            <Link href="/plaza?filter=beside"><span>곁에 둔 별</span><span>{besideCount}개<ChevronRight size={14} /></span></Link>
            <span className={styles.mineRow}><span>받은 별빛 한 줄</span><span>{lines}개</span></span>
          </div>
          <div className={`card ${styles.rules}`}>
            <span className="label-m">광장에서 지켜 주세요</span>
            <ul>
              <li>별을 누르면 글 전체를 읽을 수 있어요.</li>
              <li>마음이 닿으면 공명이나 별빛 한 줄을 남겨요. 별빛 한 줄은 별 주인만 읽어요.</li>
              <li>별빛 없이 띄운 별은 목록 아래쪽에 놓여요.</li>
              <li>불편한 별은 신고하거나 그 별지기를 차단할 수 있어요.</li>
            </ul>
          </div>
          <Link href="/records" className="btn btn-primary btn-block">내 별 나누기</Link>
        </aside>
      </div>
    </>
  );
}
