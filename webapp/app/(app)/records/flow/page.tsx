import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
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
      <p className="caption faint">숫자는 평가가 아니에요. 빛이 머물렀던 자리를 보여줄 뿐이에요.</p>
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
        <div className={`card ${styles.empty}`}>
          <h2 className="h3">흐름을 그리기엔 별이 조금 적어요</h2>
          <p className="body-m muted">지금은 별빛 받은 별이 {count}개예요. 별이 더 모이면 흐름을 선으로 이어 보여 드릴게요.</p>
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
                  <li key={m.month}><span className="caption muted">{Number(m.month.slice(5))}월{m.in_progress ? " (진행 중)" : ""}</span><i style={{ ["--v" as string]: `${Math.min(100, m.average / 10)}%` }} /><b>{m.average}</b></li>
                ))}
              </ul>
            </section>
          )}
        </>
      )}
    </div>
  );
}

/** A soft line with dots, scaled to its own range (starlight 0–1000). */
function Chart({ values, labels }: { values: number[]; labels: string[] }) {
  const W = 640, H = 180, pad = 16;
  const lo = Math.max(0, Math.min(...values) - 60), hi = Math.min(1000, Math.max(...values) + 60);
  const x = (i: number) => pad + (i * (W - pad * 2)) / Math.max(1, values.length - 1);
  const y = (v: number) => H - pad - ((v - lo) / Math.max(1, hi - lo)) * (H - pad * 2);
  const d = values.map((v, i) => `${i ? "L" : "M"}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(" ");
  const step = Math.ceil(labels.length / 8);
  return (
    <figure className={styles.chart}>
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={`마지막 ${values.at(-1)}`}>
        <path d={d} fill="none" stroke="var(--primary)" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
        {values.map((v, i) => <circle key={i} cx={x(i)} cy={y(v)} r={i === values.length - 1 ? 5 : 3.5} fill={i === values.length - 1 ? "var(--gold)" : "var(--primary-text)"}><title>{`${labels[i]} · ${v}`}</title></circle>)}
      </svg>
      <figcaption className={styles.labels}>{labels.map((l, i) => <span key={i} style={{ visibility: i % step === 0 || i === labels.length - 1 ? "visible" : "hidden" }}>{l}</span>)}</figcaption>
    </figure>
  );
}
