import type { Metadata } from "next";
import { PlazaSkeleton } from "@/components/Skeleton";
import { cookies } from "next/headers";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { PlazaRow } from "@/components/PlazaRow";
import { StarGlyph } from "@/components/StarGlyph";
import { RestrictedBanner } from "@/components/Restricted";
import { api } from "@/lib/api";
import { requireNickname, withAgo } from "@/lib/plaza";
import type { MyShare, PlazaStar } from "@/lib/types";
import styles from "./plaza.module.css";
import { PlazaWelcome } from "./Welcome";

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
    // The list and its side card as one block in the middle of wide screens (2026-11-10).
    <div className="page-column" style={{ ["--column" as string]: "1056px" }}>
      <Suspense fallback={<><Header /><PlazaSkeleton /></>}>
        <Gate searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

// Figma Web 시안 v2 · 우주 광장 (593:28550): a band of the plaza's own stars across the top is the lead.
function Header({ band = [], children }: { band?: PlazaStar[]; children?: React.ReactNode }) {
  return (
    <header className={styles.header}>
      <span className="v2-glow" style={{ ["--c" as string]: "var(--primary)", left: "-6%", top: "-260px", width: "120%", height: "520px" }} aria-hidden="true" />
      {band.length > 0 && (
        <span className={styles.band} aria-hidden="true">
          {band.slice(0, 32).map((s, i) => {
            // A fixed scatter: the same star lands in the same place every visit.
            const r = (n: number) => { const x = Math.sin((i + 1) * 12.9898 + n * 78.233) * 43758.5453; return x - Math.floor(x); };
            const size = s.has_starlight ? 9 + Math.round(r(3) * 15) : 7;
            return (
              <span key={s.id} style={{ left: `${(r(1) * 100).toFixed(1)}%`, top: `${(r(2) * 100).toFixed(1)}%` }}>
                <StarGlyph points={s.has_starlight ? s.shape?.points : 4} sharpness={s.shape?.sharpness} mood={s.mood} size={size} twinkle />
              </span>
            );
          })}
        </span>
      )}
      <h1 className="v2-hero-s">우주 광장</h1>
      {children ?? <p className="v2-body">별지기들이 나눈 별이에요. 눌러서 글을 읽고, 마음이 닿으면 공명을 남겨 보세요.</p>}
    </header>
  );
}

// W-76: the first visit gets the guide until 둘러보기 is pressed.
async function Gate({ searchParams }: Pick<PageProps<"/plaza">, "searchParams">) {
  if (!(await cookies()).get("yn_plaza_seen")) return <PlazaWelcome />;
  return (
    <Suspense fallback={<><Header /><PlazaSkeleton /></>}>
      <Plaza searchParams={searchParams} />
    </Suspense>
  );
}

const FIRST = 60, MAX = 100;

async function Plaza({ searchParams }: Pick<PageProps<"/plaza">, "searchParams">) {
  const sp = await searchParams;
  const filter: Filter = FILTERS.some((f) => f.key === sp.filter) ? (sp.filter as Filter) : "new";
  const me = await requireNickname(filter === "new" ? "/plaza" : `/plaza?filter=${filter}`);
  // 더 보기: 60 at first, then the 100 the API gives at most (it has no further pages yet).
  const more = sp.more === "1", limit = more ? MAX : FIRST;
  const [tonight, stars, mine, beside] = await Promise.all([
    api<{ count: number; mine: number }>("/v1/plaza/tonight"),
    api<{ items: PlazaStar[] }>(`/v1/plaza/stars?sort=${filter}&limit=${limit}`),
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
      <Header band={stars.items}>
        {tonight.count > 0 ? <p className={styles.tonight}>오늘 밤, {tonight.count.toLocaleString("ko-KR")}개의 마음이 모였어요</p>
          : <p className="v2-body">별지기들이 나눈 별이에요. 눌러서 글을 읽고, 마음이 닿으면 공명을 남겨 보세요.</p>}
        <p className={styles.tonightSub}>
          {tonight.mine > 0 && <>내 별 {tonight.mine}개도 함께 빛나요 · </>}
          <Link href="/settings/shares">내가 나눈 별 {mine.stars.length}개 ›</Link>
        </p>
      </Header>
      {notice && <p className={styles.notice} role="status">{notice}</p>}
      {me.plaza_restricted_until && new Date(me.plaza_restricted_until) > new Date() && <RestrictedBanner until={me.plaza_restricted_until} open={sp.restricted === "1"} />}
      <nav className={styles.sorts} aria-label="거르기">
        {FILTERS.map((f) => (
          <Link key={f.key} href={f.key === "new" ? "/plaza" : `/plaza?filter=${f.key}`} aria-current={filter === f.key ? "true" : undefined}>{f.label}</Link>
        ))}
      </nav>
      <div className={styles.body}>
        <section className={styles.records} aria-label="나눈 별">
          {rows.length === 0 ? (
            filter === "beside" ? (
              <div className={styles.listEmpty}>
                <p className="label-m">곁에 둔 별이 아직 없어요</p>
                <p className="body-s muted">마음이 닿은 별에 공명을 남기면 여기서 다시 모아 볼 수 있어요.</p>
                <Link href="/plaza" className="btn btn-secondary">새로 뜬 것 둘러보기</Link>
              </div>
            ) : (
              <p className={`body-m faint ${styles.listEmpty}`}>{filter === "similar" ? "나와 결이 비슷한 별이 아직 없어요." : "아직 광장에 뜬 별이 없어요."}</p>
            )
          ) : (
            <ul className={styles.list}>
              {rows.map(({ star, ago }) => <li key={star.id}><PlazaRow star={star} ago={ago} /></li>)}
            </ul>
          )}
          {stars.items.length >= limit && (more
            ? <p className={`caption faint ${styles.listEnd}`}>최근 {MAX}개까지 보여요</p>
            : <Link href={`/plaza?${new URLSearchParams({ ...(filter !== "new" && { filter }), more: "1" })}`} scroll={false} className={`btn btn-secondary ${styles.more}`}>더 보기</Link>)}
        </section>
        <aside className={styles.side}>
          <section className={styles.mine}>
            <h2 className={styles.sideTitle}>내 별</h2>
            <Link href="/settings/shares"><span>내가 나눈 별</span><span>{mine.stars.length}개 ›</span></Link>
            <Link href="/plaza?filter=beside"><span>곁에 둔 별</span><span>{besideCount}개 ›</span></Link>
            <span className={styles.mineRow}><span>받은 별빛 한 줄</span><span>{lines}개</span></span>
          </section>
          <hr className="v2-rule" />
          <section className={styles.rules}>
            <h2 className={styles.sideTitle} style={{ fontSize: 18 }}>광장에서 지켜 주세요</h2>
            <ul>
              <li>별을 누르면 글 전체를 읽을 수 있어요.</li>
              <li>마음이 닿으면 공명이나 별빛 한 줄을 남겨요. 별빛 한 줄은 별 주인만 읽어요.</li>
              <li>별빛 없이 띄운 별은 목록 아래쪽에 놓여요.</li>
              <li>불편한 별은 ··· 에서 신고하거나 차단할 수 있어요.</li>
            </ul>
          </section>
          <Link href="/records" className="btn btn-secondary btn-block">내 별 나누기</Link>
        </aside>
      </div>
    </>
  );
}
