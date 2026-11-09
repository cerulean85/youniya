import type { Metadata } from "next";
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
        <nav className="tabs" aria-label="상태">
          <Link href="/inquiries" aria-current={status === "new" ? "true" : undefined}>새 문의{counts ? ` ${counts.new}` : ""}</Link>
          <Link href={link({ status: "answered" })} aria-current={status === "answered" ? "true" : undefined}>답장함</Link>
        </nav>
      </div>
      <div className="split">
        <div className="card table-card">
          <table className="table">
            <thead><tr><th>유형</th><th>제목</th><th>받은 때</th><th>상태</th></tr></thead>
            <tbody>
              {items.length === 0 ? <tr><td colSpan={4} className="muted">{status === "new" ? "새 문의가 없어요." : "답장한 문의가 없어요."}</td></tr> : items.map((x) => (
                <tr key={x.id} aria-current={x.id === open?.id ? "true" : undefined}>
                  <td>{INQUIRY_KIND_LABEL[x.kind] ?? x.kind}</td>
                  <td><Link href={link({ ...(status === "answered" && { status }), id: x.id })} className="row-link">{x.title}</Link></td>
                  <td>{elapsed(x.created_at)} 전</td>
                  <td><span className={`badge ${x.status === "new" ? "badge-pending" : "badge-done"}`}>{x.status === "new" ? "새 문의" : "답장함"}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {open && (
          <section className="card panel">
            <h2>{open.title}</h2>
            <dl className="kv">
              <dt>별지기</dt>
              <dd>{open.keeper ? <Link href={`/keepers/${encodeURIComponent(open.keeper.id)}`}>{open.keeper.nickname ?? "이름 없음"} {open.keeper.no}</Link> : "로그인 전 문의"}</dd>
              <dt>이메일</dt><dd>{open.email_masked}</dd>
              {open.app && <><dt>앱</dt><dd>{open.app.platform} {open.app.version} · {open.app.device}</dd></>}
              <dt>내용</dt><dd>{open.body}</dd>
              {open.purchase && <><dt>관련 결제</dt><dd>거래번호 {open.purchase.transaction_id} · {open.purchase.status}</dd></>}
            </dl>
            {operator.role === "owner" && open.purchase && open.keeper && (
              <div className="actions">
                <Link href="/coins" className="btn">거래 확인</Link>
                <Link href={`/keepers/${encodeURIComponent(open.keeper.id)}`} className="btn">코인 지급</Link>
              </div>
            )}
            {open.replies.length > 0 && (
              <div className="thread">
                {open.replies.map((r, i) => <div key={i}><p className="faint">{dateTime(r.at)} · {r.operator.split("@")[0]}</p><p>{r.body}</p></div>)}
              </div>
            )}
            <ReplyForm id={open.id} />
          </section>
        )}
      </div>
    </>
  );
}
