import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import Link from "next/link";
import { listReports } from "@/lib/api";
import { elapsed, overdue } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import { KIND_LABEL, REASON_LABEL, STATUS_LABEL, type ReportStatus } from "@/lib/types";

export const metadata: Metadata = { title: "신고 처리" };

const TABS: ReportStatus[] = ["pending", "hidden", "done"];

// Figma A-03 (기획서 18.2 · 18.3): oldest first, so nothing waits past 24 hours.
export default async function ReportsPage({ searchParams }: PageProps<"/reports">) {
  await requireOperator();
  const wait = notConnected("reports", "신고 처리");
  if (wait) return wait;
  const sp = await searchParams;
  const status: ReportStatus = TABS.includes(sp.status as ReportStatus) ? (sp.status as ReportStatus) : "pending";
  const { items, counts } = await listReports(status);
  const other: ReportStatus | null = status !== "hidden" && counts?.hidden ? "hidden" : status !== "pending" && counts?.pending ? "pending" : null;
  return (
    <>
      <div className="head">
        <div>
          <h1>신고 처리</h1>
          <p className="muted">개인정보 노출·자해 관련은 1건만 들어와도 바로 숨기고 휴대폰으로 알려요. 괴롭힘·혐오·사칭·광고는 3건이면 숨겨요. 근무 시간 기준 24시간 안에 처리해요.</p>
        </div>
      </div>
      <nav className="tabs" aria-label="상태">
        {TABS.map((t) => (
          <Link key={t} href={t === "pending" ? "/reports" : `/reports?status=${t}`} aria-current={t === status ? "true" : undefined}>
            {STATUS_LABEL[t]}{counts && t !== "done" ? ` ${counts[t]}` : ""}
          </Link>
        ))}
      </nav>
      {items.length === 0 ? (
        <div className="empty">
          <h2>{STATUS_LABEL[status]} 신고가 없어요.</h2>
          {other && counts && <>
            <p className="muted">{STATUS_LABEL[other]} {counts[other]}건은 아직 결정을 기다려요.</p>
            <Link className="accent" href={`/reports${other === "pending" ? "" : `?status=${other}`}`}>{STATUS_LABEL[other]} 신고 보기 ›</Link>
          </>}
        </div>
      ) : (
        <section className="section">
          <table className="table">
            <thead><tr><th>접수 내용</th><th>대상</th><th>신고 사유</th><th className="num">건수</th><th>경과</th><th>상태</th></tr></thead>
            <tbody>
              {items.map((r) => {
                const top = Object.entries(r.reasons).sort((a, b) => b[1] - a[1])[0]?.[0];
                const href = `/reports/${r.kind}/${encodeURIComponent(r.target_id)}`;
                const late = r.status === "pending" && overdue(r.first_reported_at);
                return (
                  <tr key={r.id}>
                    <td><Link href={href} className="row-link">{r.preview}</Link></td>
                    <td>{KIND_LABEL[r.kind]}</td>
                    <td>{REASON_LABEL[top] ?? top}{Object.keys(r.reasons).length > 1 ? " 외" : ""}</td>
                    <td className="num">{r.reports}</td>
                    <td className={late ? "overdue" : "muted"}>{elapsed(r.first_reported_at)}</td>
                    <td><span className={`badge badge-${r.status}`}>{STATUS_LABEL[r.status]}</span></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <p className="faint">24시간 넘은 신고는 경과가 노란색이에요. 행을 누르면 상세로 가요.</p>
        </section>
      )}
    </>
  );
}
