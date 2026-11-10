import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ChevronLeft, StarFilled } from "@/components/icons";
import { api } from "@/lib/api";
import type { StarSummary } from "@/lib/types";
import styles from "./flow.module.css";

export const metadata: Metadata = { title: "나의 별빛 흐름" };

type Trend = { recent: { star_id: string; created_at: string; starlight: number }[]; average: number | null; monthly: { month: string; average: number; in_progress: boolean }[]; enough: boolean };
const RANGES = [["recent", "최근 별"], ["monthly", "월평균"], ["all", "전체"]] as const;
type Range = (typeof RANGES)[number][0];

// iOS 82 / 109 (BrightnessFlowView), on the web from 기록: only against my own past, never others.
export default function FlowPage({ searchParams }: PageProps<"/records/flow">) {
  return (
    <>
      <Link href="/records" className={styles.back}><ChevronLeft size={16} />기록</Link>
      <header className={styles.header}>
        <h1 className="h1">나의 별빛 흐름</h1>
        <p className="body-m muted">다른 사람과 비교하지 않아요. 지난날의 나와만 나란히 놓아 봐요.</p>
      </header>
      <Suspense fallback={<div className={styles.loading} aria-busy="true" />}>
        <Flow searchParams={searchParams} />
      </Suspense>
      <p className={`caption faint ${styles.note}`}>숫자는 평가가 아니에요. 빛이 머물렀던 자리를 보여줄 뿐이에요.</p>
    </>
  );
}

const md = (iso: string) => new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", month: "numeric", day: "numeric" }).format(new Date(iso)).replace(/\. /g, "/").replace(/\.$/, "");

async function Flow({ searchParams }: Pick<PageProps<"/records/flow">, "searchParams">) {
  const sp = await searchParams;
  const range: Range = RANGES.some(([k]) => k === sp.range) ? (sp.range as Range) : "recent";
  await connection();
  const [trend, all] = await Promise.all([
    api<Trend>("/v1/starlight/trend"),
    range === "all" ? api<{ items: StarSummary[] }>("/v1/stars?state=floated&limit=200") : null,
  ]);
  const lit = (all?.items ?? []).filter((s) => s.starlight != null).sort((a, b) => a.created_at.localeCompare(b.created_at));
  const series = range === "monthly"
    ? { title: "달마다 평균", values: trend.monthly.slice(-8).map((m) => m.average), labels: trend.monthly.slice(-8).map((m) => `${Number(m.month.slice(5))}월${m.in_progress ? "·" : ""}`) }
    : range === "all"
      ? { title: `전체 ${lit.length}개의 별`, values: lit.map((s) => s.starlight!), labels: lit.map((s) => md(s.created_at)) }
      : { title: `최근 ${trend.recent.slice(-8).length}개의 별`, values: trend.recent.slice(-8).map((r) => r.starlight), labels: trend.recent.slice(-8).map((r) => md(r.created_at)) };
  const count = trend.recent.length;
  return (
    <div className={styles.body}>
      <nav className={styles.chips} aria-label="범위">
        {RANGES.map(([k, l]) => <Link key={k} href={k === "recent" ? "/records/flow" : `/records/flow?range=${k}`} aria-current={k === range ? "true" : undefined}>{l}</Link>)}
      </nav>
      {!trend.enough && count < 3 ? (
        <div className={styles.empty}>
          <StarFilled size={28} className={styles.emptyMark} />
          <h2 className="h3">흐름을 그리기엔 별이 조금 적어요</h2>
          <p className="body-m muted">지금은 별이 {count}개예요. 별이 더 모이면<br />흐름을 선으로 이어 보여 드릴게요.</p>
        </div>
      ) : (
        <>
          <section className={`card ${styles.card}`} aria-label={series.title}>
            <div className={styles.cardHead}><span className="label-m">{series.title}</span>{series.values.length > 0 && <span className="caption faint">평균 {Math.round(series.values.reduce((a, b) => a + b, 0) / series.values.length)}</span>}</div>
            {series.values.length < 2 ? <p className="body-s muted">별을 두 개 이상 띄우면 흐름이 그려져요.</p> : <Chart values={series.values} labels={series.labels} />}
          </section>
          {trend.monthly.length > 0 && (
            <section className={`card ${styles.card}`} aria-label="월평균 별빛">
              <span className="label-m">월평균 별빛</span>
              <ul className={styles.months}>
                {trend.monthly.slice(-6).map((m) => (
                  <li key={m.month} data-now={m.in_progress || undefined}><span className="caption muted">{Number(m.month.slice(5))}월</span><i style={{ ["--v" as string]: `${Math.min(100, m.average / 10)}%` }} /><b>{m.average}{m.in_progress ? " · 진행 중" : ""}</b></li>
                ))}
              </ul>
            </section>
          )}
        </>
      )}
    </div>
  );
}

/** W-71: grid lines with values, a soft area under the line, and the latest star in gold with its number. */
function Chart({ values, labels }: { values: number[]; labels: string[] }) {
  const W = 640, H = 200, left = 40, right = 24, top = 24, bottom = 16;
  const lo = Math.max(0, Math.floor((Math.min(...values) - 80) / 100) * 100), hi = Math.min(1000, Math.ceil((Math.max(...values) + 80) / 100) * 100);
  const x = (i: number) => left + (i * (W - left - right)) / Math.max(1, values.length - 1);
  const y = (v: number) => H - bottom - ((v - lo) / Math.max(1, hi - lo)) * (H - top - bottom);
  const pts = values.map((v, i) => [x(i), y(v)] as const);
  const d = pts.map(([px, py], i) => `${i ? "L" : "M"}${px.toFixed(1)} ${py.toFixed(1)}`).join(" ");
  const area = `${d} L${pts.at(-1)![0].toFixed(1)} ${H - bottom} L${pts[0][0].toFixed(1)} ${H - bottom} Z`;
  const grid = [hi, Math.round((hi + lo) / 2 / 100) * 100, lo];
  const step = Math.ceil(labels.length / 6);
  const [lx, ly] = pts.at(-1)!;
  return (
    <figure className={styles.chart}>
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={`마지막 ${values.at(-1)}`}>
        <defs><linearGradient id="flowFill" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stopColor="var(--primary)" stopOpacity="0.35" /><stop offset="1" stopColor="var(--primary)" stopOpacity="0.02" /></linearGradient></defs>
        {grid.map((g) => <g key={g}><line x1={left} x2={W - right} y1={y(g)} y2={y(g)} stroke="#fff" strokeOpacity={0.08} /><text x={0} y={y(g) + 4} fontSize={11} fill="var(--text-3)">{g}</text></g>)}
        <path d={area} fill="url(#flowFill)" />
        <path d={d} fill="none" stroke="var(--primary)" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
        {pts.map(([px, py], i) => i < pts.length - 1 && <circle key={i} cx={px} cy={py} r={3} fill="var(--primary-text)"><title>{`${labels[i]} · ${values[i]}`}</title></circle>)}
        <circle cx={lx} cy={ly} r={5} fill="var(--gold)" />
        <text x={lx} y={ly - 10} fontSize={12} textAnchor="end" fill="var(--gold)">{values.at(-1)}</text>
      </svg>
      <figcaption className={styles.labels} style={{ paddingLeft: left - 8 }}>{labels.map((l, i) => <span key={i} style={{ visibility: i % step === 0 || i === labels.length - 1 ? "visible" : "hidden" }}>{l}</span>)}</figcaption>
    </figure>
  );
}
