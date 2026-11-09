import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import { audit } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import { ACTION_LABEL } from "@/lib/types";

export const metadata: Metadata = { title: "운영 기록" };

// Figma A-13: who did what, to which target, and why. Owners only.
export default async function AuditPage() {
  await requireOperator(["owner"]);
  const wait = notConnected("audit", "운영 기록");
  if (wait) return wait;
  const items = await audit();
  return (
    <>
      <div className="head"><div><h1>운영 기록</h1><p className="muted">운영자의 모든 조회와 조치가 사유와 함께 남아요. 지울 수 없어요.</p></div></div>
      <div className="card table-card">
        <table className="table">
          <thead><tr><th>시각</th><th>운영자</th><th>조치</th><th>대상</th><th>사유</th></tr></thead>
          <tbody>
            {items.length === 0 ? <tr><td colSpan={5} className="muted">아직 기록이 없어요.</td></tr> : items.map((a, i) => (
              <tr key={i}><td>{dateTime(a.at)}</td><td>{a.operator}</td><td>{ACTION_LABEL[a.action] ?? a.action}</td><td>{a.target}</td><td>{a.reason}</td></tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
