import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import Link from "next/link";
import { getInquiry, listInquiries } from "@/lib/api";
import { dateTime, elapsed } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import { INQUIRY_KIND_LABEL, type InquiryStatus } from "@/lib/types";
import { ReplyForm } from "./ReplyForm";

export const metadata: Metadata = { title: "문의" };

// Figma A-07: the list and the chosen inquiry side by side. Email shows masked.
export default async function InquiriesPage({ searchParams }: PageProps<"/inquiries">) {
  const { operator } = await requireOperator();
  const wait = notConnected("inquiries", "문의");
  if (wait) return wait;
  const sp = await searchParams;
  const status: InquiryStatus = sp.status === "answered" ? "answered" : "new";
  const { items, counts } = await listInquiries(status);
  const id = typeof sp.id === "string" ? sp.id : items[0]?.id;
  const open = id ? await getInquiry(id).catch(() => null) : null;
  const link = (q: Record<string, string>) => `/inquiries?${new URLSearchParams(q)}`;
  return (
    <>
      <div className="head">
        <div><h1>문의</h1><p className="muted">답장은 문의할 때 적은 이메일로 보내져요.</p></div>
      </div>
      <nav className="tabs" aria-label="상태">
        <Link href="/inquiries" aria-current={status === "new" ? "true" : undefined}>새 문의{counts ? ` ${counts.new}` : ""}</Link>
        <Link href={link({ status: "answered" })} aria-current={status === "answered" ? "true" : undefined}>답장함</Link>
      </nav>
      {items.length === 0 ? (
        <div className="empty">
          <h2>{status === "new" ? "새 문의가 없어요." : "답장한 문의가 없어요."}</h2>
          {status === "new" && <Link className="accent" href={link({ status: "answered" })}>답장함 보기 ›</Link>}
        </div>
      ) : (
      <div className="split">
        <table className="table">
          <thead><tr><th>유형</th><th>제목</th><th>받은 때</th></tr></thead>
          <tbody>
            {items.map((x) => (
              <tr key={x.id} aria-current={x.id === open?.id ? "true" : undefined}>
                <td>{INQUIRY_KIND_LABEL[x.kind] ?? x.kind}</td>
                <td><Link href={link({ ...(status === "answered" && { status }), id: x.id })} className="row-link">{x.title}</Link></td>
                <td className="muted">{elapsed(x.created_at)} 전</td>
              </tr>
            ))}
          </tbody>
        </table>
        {open ? (
          <section className="detail">
            <h2>{open.title}</h2>
            <p className="meta">
              {open.keeper ? <Link className="accent" href={`/keepers/${encodeURIComponent(open.keeper.id)}`}>{open.keeper.nickname ?? "이름 없음"} · {open.keeper.no} ›</Link> : <span>로그인 전 문의</span>}
              <span>{open.email_masked}</span>
              {open.app && <span>{open.app.platform} {open.app.version} · {open.app.device}</span>}
              <span className={`badge ${open.status === "new" ? "badge-pending" : "badge-done"}`}>{open.status === "new" ? "새 문의" : "답장함"}</span>
            </p>
            <p style={{ whiteSpace: "pre-wrap" }}>{open.body}</p>
            {open.purchase && (
              <div className="related">
                <span className="faint">관련 결제</span>
                <span>거래번호 {open.purchase.transaction_id} · {open.purchase.status}</span>
                {operator.role === "owner" && open.keeper && (
                  <span className="go">
                    <Link className="accent" href="/coins">거래 확인 ›</Link>
                    <Link className="accent" href={`/keepers/${encodeURIComponent(open.keeper.id)}`}>코인 지급 ›</Link>
                  </span>
                )}
              </div>
            )}
            {open.replies.length > 0 && (
              <div className="thread">
                {open.replies.map((r, i) => <div key={i}><p className="faint">{dateTime(r.at)} · {r.operator.split("@")[0]}{r.sent === false ? " · 발송 실패" : ""}</p><p>{r.body}</p></div>)}
              </div>
            )}
            <ReplyForm id={open.id} />
          </section>
        ) : <p className="muted">문의를 불러오지 못했어요.</p>}
      </div>
      )}
    </>
  );
}
