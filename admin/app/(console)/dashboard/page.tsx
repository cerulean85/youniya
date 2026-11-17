import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import Link from "next/link";
import { Stat } from "@/components/Stat";
import { getDashboard, listReports } from "@/lib/api";
import { ready } from "@/lib/config";
import { elapsed, longToday, num, time, won } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import type { Range } from "@/lib/types";

export const metadata: Metadata = { title: "대시보드" };

const RANGES: [Range, string][] = [["today", "오늘"], ["week", "이번 주"], ["month", "이번 달"]];
const EVENT: Record<string, [string, string]> = { hidden: ["badge-hidden", "숨김"], alert: ["badge-hidden", "경보"], done: ["badge-done", "처리 완료"], pending: ["badge-pending", "대기"], ok: ["badge-muted", "정상"] };

// Figma A2-01 (owners): what to handle now first, then counts only.
export default async function DashboardPage({ searchParams }: PageProps<"/dashboard">) {
  await requireOperator(["owner"]);
  const wait = notConnected("owner", "대시보드");
  if (wait) return wait;
  const sp = await searchParams;
  const range = RANGES.some(([k]) => k === sp.range) ? (sp.range as Range) : "today";
  const [d, pending] = await Promise.all([getDashboard(range), ready("reports") ? listReports("pending").catch(() => null) : null]);
  const label = RANGES.find(([k]) => k === range)![1];
  const oldest = pending?.items.map((r) => r.first_reported_at).sort()[0];
  const rp = d.reports_pending, iq = d.inquiries_new;
  const reportSub = [rp.overdue != null ? `24시간 넘은 것 ${rp.overdue}건` : null, oldest ? `가장 오래된 것 ${elapsed(oldest)}` : null].filter(Boolean).join(" · ");
  return (
    <>
      <div className="head">
        <div><h1>대시보드</h1><p className="muted">{longToday()} · Asia/Seoul 기준</p></div>
        <nav className="segmented" aria-label="기간">{RANGES.map(([k, l]) => <Link key={k} href={k === "today" ? "/dashboard" : `/dashboard?range=${k}`} aria-current={k === range ? "true" : undefined}>{l}</Link>)}</nav>
      </div>
      <section className="section">
        <h2>지금 처리할 일</h2>
        <div className="queue">
          <div className="queue-row">
            <b>신고 대기 {rp.count}건</b>
            {reportSub && <span className={rp.overdue ? "overdue" : "sub"}>{reportSub}</span>}
            <Link className="accent go" href="/reports">신고 처리로 ›</Link>
          </div>
          <div className="queue-row">
            <b>새 문의 {iq.count}건</b>
            {iq.avg_first_reply_hours != null && <span className="sub">평균 첫 답장 {iq.avg_first_reply_hours}시간</span>}
            <Link className="accent go" href="/inquiries">문의로 ›</Link>
          </div>
        </div>
      </section>
      <div className="strip">
        <Stat label={`${label} 띄운 별`} value={num(d.stars.total)} sub={`별빛 받고 ${num(d.stars.lit)} · 별빛 없이 ${num(d.stars.unlit)}`} />
        <Stat label="새 별지기" value={num(d.new_keepers.count)} sub={d.new_keepers.delta != null ? `어제보다 ${d.new_keepers.delta >= 0 ? "+" : ""}${d.new_keepers.delta}` : undefined} />
        <Stat label="이번 달 AI 원가" value={won(d.ai_cost_month.krw)} sub={d.ai_cost_month.starlight_share != null ? `별빛 받기 ${d.ai_cost_month.starlight_share}%` : d.crisis_stars != null ? `위기 신호 감지 ${d.crisis_stars}건` : undefined} />
      </div>
      <div className="columns">
        <section className="section grow">
          <h2>알림</h2>
          <table className="table">
            <thead><tr><th>시각</th><th>알림</th><th>상태</th></tr></thead>
            <tbody>{d.events.length === 0 ? <tr><td colSpan={3} className="muted">새 알림이 없어요.</td></tr> : d.events.map((e, i) => (
              <tr key={i}>
                <td>{time(e.at)}</td>
                <td>{e.href ? <Link href={e.href} className="row-link">{e.text}</Link> : e.text}</td>
                <td><span className={`badge ${EVENT[e.status][0]}`}>{EVENT[e.status][1]}</span></td>
              </tr>
            ))}</tbody>
          </table>
        </section>
        <section className="section side">
          <h2>오늘의 결제</h2>
          <dl className="rows compact">
            <div><dt>충전</dt><dd>{won(d.payments_today.charge_krw)} · {num(d.payments_today.charge_count)}건</dd></div>
            {d.payments_today.refund_krw != null && <div><dt>환불 회수</dt><dd>{won(d.payments_today.refund_krw)} · {d.payments_today.refund_count ?? 0}건</dd></div>}
            {d.payments_today.used ? <div><dt>코인 사용</dt><dd>별빛 받기 {num(d.payments_today.used.starlight)}</dd></div>
              : d.payments_today.coins != null && <div><dt>충전 코인</dt><dd>{num(d.payments_today.coins)}코인</dd></div>}
            <div><dt>멤버십</dt><dd>v1.1 이후 열려요</dd></div>
          </dl>
          <Link href="/coins" className="accent" style={{ paddingTop: 8 }}>코인·결제 보기 ›</Link>
        </section>
      </div>
    </>
  );
}
