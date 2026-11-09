import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ApiError, getReport } from "@/lib/api";
import { dateTime, elapsed, time } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import { ACTION_LABEL, INSTANT_REASONS, KIND_LABEL, REASON_LABEL, STATUS_LABEL, type ActionKind, type ReportDetail, type ReportKind } from "@/lib/types";
import { ActionPanel } from "./ActionPanel";

export const metadata: Metadata = { title: "신고 상세" };

const KINDS: ReportKind[] = ["star", "nebula", "star_line", "line", "nickname"];

// Figma A-04 (18.1): only what the plaza shows; never unshared writing, starlight numbers or telescope results.
export default async function ReportPage({ params }: PageProps<"/reports/[kind]/[id]">) {
  await requireOperator();
  const wait = notConnected("reports", "신고 상세");
  if (wait) return wait;
  const { kind, id } = await params;
  if (!KINDS.includes(kind as ReportKind)) notFound();
  let r: ReportDetail;
  try {
    r = await getReport(kind as ReportKind, decodeURIComponent(id));
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  const first = r.reports.map((x) => x.at).sort()[0];
  const instant = r.reports.some((x) => INSTANT_REASONS.includes(x.reason));
  // A name can't be taken down or restored (422 wrong_action); ask for a new one instead.
  const nick = r.kind === "nickname";
  const actions: ActionKind[] = [!nick && (r.status === "hidden" || r.auto_hidden) ? "restore" : null, nick ? null : "take_down",
    "request_rename", "restrict_7d", "restrict_30d", "note"].filter(Boolean) as ActionKind[];
  return (
    <>
      <div className="head">
        <div>
          <h1>신고 상세 · {KIND_LABEL[r.kind]} #{r.target_id}</h1>
          <p className="muted">신고 {r.reports.length}건 · {r.auto_hidden ? "광장에서 자동으로 숨김" : STATUS_LABEL[r.status]}{first ? ` · 접수 ${elapsed(first)} 전` : ""}</p>
        </div>
        <Link href="/reports" className="btn">‹ 목록</Link>
      </div>
      <div className="cols">
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <section className="card panel">
            <h2>광장에 공개된 내용</h2>
            <dl className="kv">
              <dt>별지기</dt><dd><Link href={`/keepers/${encodeURIComponent(r.keeper.id)}`}>{r.keeper.nickname ?? "이름 없음"}{r.keeper.no ? ` (${r.keeper.no})` : ""}</Link></dd>
              {r.content.shared_at && <><dt>나눈 날</dt><dd>{dateTime(r.content.shared_at)}</dd></>}
              {r.content.quote && <><dt>대표 문장</dt><dd>“{r.content.quote}”</dd></>}
              {r.content.body_masked && <><dt>글 전체</dt><dd>{r.content.body_masked}</dd></>}
              {r.content.line && <><dt>별빛 한 줄</dt><dd>“{r.content.line}”</dd></>}
              {r.content.nickname && r.kind === "nickname" && <><dt>별지기 이름</dt><dd>{r.content.nickname}</dd></>}
            </dl>
            <p className="faint">운영자는 우주 광장에 공개된 내용만 볼 수 있어요. 나누지 않은 글, 별빛 수치, 망원경 결과는 볼 수 없어요.</p>
          </section>
          <section className="card table-card">
            <table className="table">
              <thead><tr><th>신고한 별지기</th><th>사유</th><th>메모</th><th>시각</th></tr></thead>
              <tbody>
                {r.reports.map((x, i) => (
                  <tr key={i}><td>{x.reporter_no}</td><td>{REASON_LABEL[x.reason] ?? x.reason}</td><td>{x.note || "—"}</td><td>{time(x.at)}</td></tr>
                ))}
              </tbody>
            </table>
          </section>
          {r.actions.length > 0 && (
            <section className="card table-card">
              <table className="table">
                <thead><tr><th>조치</th><th>사유</th><th>운영자</th><th>시각</th></tr></thead>
                <tbody>
                  {r.actions.map((a, i) => (
                    <tr key={i}><td>{ACTION_LABEL[a.action] ?? a.action}</td><td>{a.reason}</td><td>{a.operator.split("@")[0]}</td><td>{dateTime(a.at)}</td></tr>
                  ))}
                </tbody>
              </table>
            </section>
          )}
        </div>
        <aside className="card panel">
          <h2>조치</h2>
          <p className="muted">조치는 별지기에게 앱 알림으로 알려지고, 운영 기록에 남아요.</p>
          <p className="rule">숨김 규칙: {instant ? "개인정보 노출·자해 관련은 1건이면 바로 숨겨요." : "괴롭힘·혐오·사칭·광고는 3건이 쌓이면 자동으로 숨겨요. 개인정보 노출·자해 관련은 1건이면 바로 숨겨요."}</p>
          <dl className="kv"><dt>현재</dt><dd>{r.auto_hidden ? "광장에서 숨김(자동)" : STATUS_LABEL[r.status]}</dd></dl>
          <ActionPanel kind={r.kind} id={r.target_id} actions={actions} />
        </aside>
      </div>
    </>
  );
}
