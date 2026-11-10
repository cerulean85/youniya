import type { Metadata } from "next";
import { RecordsSkeleton } from "@/components/Skeleton";
import Link from "next/link";
import { Suspense } from "react";
import { ChevronLeft, ChevronRight } from "@/components/icons";
import { StarRow } from "@/components/StarRow";
import { api } from "@/lib/api";
import { kst, monthLabel, MOODS, shiftMonth, subject } from "@/lib/format";
import type { StarSummary, Summary } from "@/lib/types";
import styles from "./records.module.css";

export const metadata: Metadata = { title: "기록" };

type Params = { view?: string; state?: string; mood?: string; q?: string; month?: string; day?: string; before?: string };
type Calendar = { month: string; days: { day: number; count: number }[] };
type List = { items: StarSummary[]; next_before: string | null };

const one = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);
const href = (p: Params) => {
  const q = new URLSearchParams(Object.entries(p).filter(([, v]) => v) as [string, string][]).toString();
  return q ? `/records?${q}` : "/records";
};

// Figma W-14 (기록 · 목록) and W-28 (기록 · 달력).
export default function RecordsPage({ searchParams }: PageProps<"/records">) {
  return (
    <Suspense fallback={<><Header total={null} /><RecordsSkeleton /></>}>
      <Records searchParams={searchParams} />
    </Suspense>
  );
}

function Header({ total }: { total: number | null }) {
  return (
    <header className={styles.header}>
      <h1 className="h1">기록</h1>
      <p className="body-m muted">{total == null ? " " : `지금까지 띄운 별 ${total}개`}</p>
      <Link href="/records/flow" className={styles.flowLink}>밝기 흐름 보기 ›</Link>
    </header>
  );
}

async function Records({ searchParams }: Pick<PageProps<"/records">, "searchParams">) {
  const raw = await searchParams;
  const p: Params = Object.fromEntries(Object.entries(raw).map(([k, v]) => [k, one(v)]));
  const calendar = p.view === "calendar";
  const summary = await api<Summary>("/v1/stars/summary");
  return (
    <>
      <Header total={summary.total} />
      <div className={styles.controls}>
        <nav className={styles.segment} aria-label="보기">
          <Link href={href({ ...p, view: undefined, day: undefined, before: undefined })} aria-current={!calendar ? "page" : undefined}>목록</Link>
          <Link href={href({ ...p, view: "calendar", before: undefined })} aria-current={calendar ? "page" : undefined}>달력</Link>
        </nav>
        {!calendar && (
          <form action="/records" className={styles.search} role="search">
            {p.state && <input type="hidden" name="state" value={p.state} />}
            {p.mood && <input type="hidden" name="mood" value={p.mood} />}
            <input type="search" name="q" defaultValue={p.q ?? ""} maxLength={50} placeholder="제목이나 내용으로 찾기" aria-label="기록 검색" />
          </form>
        )}
      </div>
      {calendar ? <CalendarView p={p} /> : <ListView p={p} />}
    </>
  );
}

function Filters({ p }: { p: Params }) {
  const chips: { label: string; to: Params; on: boolean; color?: string }[] = [
    { label: "전체", to: { q: p.q }, on: !p.state && !p.mood },
    { label: "별빛 받은 별", to: { q: p.q, state: "floated" }, on: p.state === "floated" },
    { label: "별빛 없는 별", to: { q: p.q, state: "kept" }, on: p.state === "kept" },
    ...MOODS.map((m) => ({ label: m.label, to: { q: p.q, mood: m.key }, on: p.mood === m.key, color: m.color })),
  ];
  return (
    <nav className={styles.filters} aria-label="거르기">
      {chips.map((c) => (
        <Link key={c.label} href={href(c.to)} className={styles.chip} aria-current={c.on ? "true" : undefined} style={c.color ? { ["--c" as string]: c.color } : undefined}>{c.label}</Link>
      ))}
    </nav>
  );
}

async function ListView({ p }: { p: Params }) {
  const q = new URLSearchParams({ limit: "30" });
  for (const k of ["state", "mood", "q", "before"] as const) if (p[k]) q.set(k, p[k]!);
  const list = await api<List>(`/v1/stars?${q}`);
  const groups = new Map<string, StarSummary[]>();
  for (const s of list.items) {
    const m = kst(s.created_at).month;
    groups.set(m, [...(groups.get(m) ?? []), s]);
  }
  return (
    <>
      <Filters p={p} />
      {list.items.length === 0 ? (
        <div className={`card ${styles.empty}`}>
          <p className="h3">{p.q || p.state || p.mood ? "맞는 별이 없어요" : "아직 기록이 없어요"}</p>
          <p className="body-m muted">{p.q || p.state || p.mood ? "다른 말로 찾거나 거르기를 바꿔 보세요." : "오늘의 마음을 적으면 이곳에 쌓여요."}</p>
          {(p.q || p.state || p.mood) ? <Link href="/records" className="btn btn-secondary">전체 보기</Link> : <Link href="/write" className="btn btn-primary">별 만들기</Link>}
        </div>
      ) : (
        <div className={styles.list}>
          {/* W-70: a search shows how many stars hold the words, in titles and writing. */}
          {p.q && <div className={styles.groupHead}><span className="label-m">&lsquo;{p.q}&rsquo;{subject(p.q).slice(p.q.length)} 담긴 별 {list.items.length}{list.next_before ? "개 이상" : "개"}</span><span className="caption faint">제목 · 본문</span></div>}
          {[...groups].map(([month, stars]) => (
            <section key={month} className={styles.group} aria-label={monthLabel(month)}>
              <div className={styles.groupHead}><span className="label-m">{monthLabel(month)}</span><span className="caption faint">별 {stars.length}개</span></div>
              {stars.map((s) => <StarRow key={s.id} star={s} />)}
            </section>
          ))}
          {list.next_before && <Link href={href({ ...p, before: list.next_before })} className={`btn btn-ghost ${styles.more}`}>이전 기록 더 보기</Link>}
        </div>
      )}
    </>
  );
}

async function CalendarView({ p }: { p: Params }) {
  const today = kst(new Date());
  const month = /^\d{4}-\d{2}$/.test(p.month ?? "") ? p.month! : today.month;
  const [summary, list] = await Promise.all([
    api<Summary & { calendar: Calendar | null }>(`/v1/stars/summary?month=${month}`),
    api<List>(`/v1/stars?month=${month}&limit=200`),
  ]);
  const byDay = new Map<number, StarSummary[]>();
  for (const s of list.items) {
    const d = kst(s.created_at).d;
    byDay.set(d, [...(byDay.get(d) ?? []), s]);
  }
  const y = Number(month.slice(0, 4)), m = Number(month.slice(5));
  const first = new Date(Date.UTC(y, m - 1, 1)).getUTCDay();
  const days = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const isThisMonth = month === today.month;
  const selected = Number(p.day) || (isThisMonth ? today.d : [...byDay.keys()].sort((a, b) => b - a)[0] ?? 1);
  const cells = [...Array(first).fill(null), ...Array.from({ length: days }, (_, i) => i + 1)];
  const picked = (byDay.get(selected) ?? []).sort((a, b) => a.created_at.localeCompare(b.created_at));
  const floated = list.items.filter((s) => s.state === "floated");
  const brightest = floated.reduce<StarSummary | null>((b, s) => (!b || (s.starlight ?? 0) > (b.starlight ?? 0) ? s : b), null);
  const weekday = ["일", "월", "화", "수", "목", "금", "토"][new Date(Date.UTC(y, m - 1, selected)).getUTCDay()];
  return (
    <div className={styles.calBody}>
      <section className={`card ${styles.calendar}`} aria-label={monthLabel(month)}>
        <div className={styles.calHead}>
          <Link href={href({ view: "calendar", month: shiftMonth(month, -1) })} aria-label="이전 달"><ChevronLeft size={18} /></Link>
          <span className="h3">{monthLabel(month)}</span>
          <Link href={href({ view: "calendar", month: shiftMonth(month, 1) })} aria-label="다음 달"><ChevronRight size={18} /></Link>
          <span className={styles.calCount}>별 {summary.calendar?.days.reduce((n, d) => n + d.count, 0) ?? list.items.length}개</span>
        </div>
        <div className={styles.grid} role="grid">
          {["일", "월", "화", "수", "목", "금", "토"].map((d) => <span key={d} className={styles.weekday} role="columnheader">{d}</span>)}
          {cells.map((day, i) => day == null ? <span key={`e${i}`} /> : (
            <Link key={day} href={href({ view: "calendar", month, day: String(day) })} className={styles.day} role="gridcell"
              aria-current={day === selected ? "date" : undefined} data-today={isThisMonth && day === today.d}>
              <span className="label-s">{day}</span>
              {(byDay.get(day) ?? []).slice(0, 2).map((s) => (
                <span key={s.id} className={styles.entry} data-floated={s.state === "floated"}>{s.title || "제목 없는 별"}</span>
              ))}
              {(byDay.get(day)?.length ?? 0) > 2 && <span className="caption faint">+{byDay.get(day)!.length - 2}</span>}
            </Link>
          ))}
        </div>
      </section>
      <aside className={styles.dayPanel}>
        <h2 className="h3">{m}월 {selected}일 {weekday}요일</h2>
        <p className="caption faint">{picked.length ? `별 ${picked.length}개` : "이날은 별이 없어요"}</p>
        {picked.map((s) => <StarRow key={s.id} star={s} />)}
        <div className={`card ${styles.monthSum}`}>
          <span className="label-m">{m}월에는</span>
          <div><span className="body-s muted">별빛 받은 별</span><span className="label-s">{floated.length}개</span></div>
          <div><span className="body-s muted">별빛 없는 별</span><span className="label-s">{list.items.length - floated.length}개</span></div>
          {brightest && <div><span className="body-s muted">가장 밝은 별</span><span className="label-s">{brightest.title || "제목 없는 별"} · {brightest.starlight}</span></div>}
        </div>
      </aside>
    </div>
  );
}

