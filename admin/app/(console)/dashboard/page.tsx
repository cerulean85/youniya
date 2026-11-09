import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import Link from "next/link";
import { Stat } from "@/components/Stat";
import { getDashboard } from "@/lib/api";
import { longToday, num, time, won } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import type { Range } from "@/lib/types";

export const metadata: Metadata = { title: "대시보드" };

const RANGES: [Range, string][] = [["today", "오늘"], ["week", "이번 주"], ["month", "이번 달"]];
const EVENT: Record<string, [string, string]> = { hidden: ["badge-hidden", "숨김"], alert: ["badge-hidden", "경보"], done: ["badge-done", "처리 완료"], pending: ["badge-pending", "대기"], ok: ["badge-done", "정상"] };

// Figma A-02 (owners). Counts only.
export default async function DashboardPage({ searchParams }: PageProps<"/dashboard">) {
  await requireOperator(["owner"]);
  const wait = notConnected("owner", "대시보드");
  if (wait) return wait;
  const sp = await searchParams;
  const range = RANGES.some(([k]) => k === sp.range) ? (sp.range as Range) : "today";
  const d = await getDashboard(range);
  const label = RANGES.find(([k]) => k === range)![1];
  return (
    <>
      <div className="head">
        <div><h1>대시보드</h1><p className="muted">{longToday()} · Asia/Seoul 기준</p></div>
        <nav className="tabs">{RANGES.map(([k, l]) => <Link key={k} href={k === "today" ? "/dashboard" : `/dashboard?range=${k}`} aria-current={k === range ? "true" : undefined}>{l}</Link>)}</nav>
      </div>
      <div className="stats five">
        <Stat label={`${label} 띄운 별`} value={num(d.stars.total)} sub={`별빛 받고 ${num(d.stars.lit)} · 별빛 없이 ${num(d.stars.unlit)}`} />
        <Stat label="새 별지기" value={num(d.new_keepers.count)} sub={`어제보다 ${d.new_keepers.delta >= 0 ? "+" : ""}${d.new_keepers.delta}`} />
        <Stat label="신고 대기" value={d.reports_pending.count} tone={d.reports_pending.count ? "amber" : undefined} sub={`24시간 넘은 것 ${d.reports_pending.overdue}건`} />
        <Stat label="새 문의" value={d.inquiries_new.count} sub={d.inquiries_new.avg_first_reply_hours != null ? `평균 첫 답장 ${d.inquiries_new.avg_first_reply_hours}시간` : undefined} />
        <Stat label="이번 달 AI 원가" value={won(d.ai_cost_month.krw)} sub={`별빛 받기 ${d.ai_cost_month.starlight_share}% · 망원경 ${d.ai_cost_month.telescope_share}%`} />
      </div>
      <div className="split">
        <div className="card table-card">
          <table className="table">
            <thead><tr><th>시각</th><th>알림</th><th>상태</th></tr></thead>
            <tbody>{d.events.map((e, i) => <tr key={i}><td>{time(e.at)}</td><td>{e.text}</td><td><span className={`badge ${EVENT[e.status][0]}`}>{EVENT[e.status][1]}</span></td></tr>)}</tbody>
          </table>
        </div>
        <section className="card panel">
          <h2>오늘의 결제</h2>
          <dl className="kv">
            <dt>충전</dt><dd>{won(d.payments_today.charge_krw)} · {num(d.payments_today.charge_count)}건</dd>
            <dt>환불 회수</dt><dd>{won(d.payments_today.refund_krw)} · {d.payments_today.refund_count}건</dd>
            <dt>코인 사용</dt><dd>별빛 받기 {num(d.payments_today.used.starlight)} · 망원경 {num(d.payments_today.used.telescope)}</dd>
            <dt>멤버십</dt><dd>v1.1 이후 열려요</dd>
          </dl>
          <Link href="/coins" className="btn" style={{ alignSelf: "flex-start" }}>코인·결제 보기</Link>
        </section>
      </div>
    </>
  );
}
