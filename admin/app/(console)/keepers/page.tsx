import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import Link from "next/link";
import { listKeepers } from "@/lib/api";
import { requireOperator } from "@/lib/session";
import { PROVIDER_LABEL } from "@/lib/types";

export const metadata: Metadata = { title: "별지기" };

const FILTERS = [["all", "전체"], ["restricted", "제한"], ["reported", "신고 받음"], ["invite", "초대 계정"]] as const;

// Figma A-05: find by 별지기 이름 or #번호. Counts only; no writing.
export default async function KeepersPage({ searchParams }: PageProps<"/keepers">) {
  const { operator } = await requireOperator();
  const wait = notConnected("keepers", "별지기");
  if (wait) return wait;
  const sp = await searchParams;
  const q = typeof sp.q === "string" ? sp.q.slice(0, 40) : "";
  const filter = FILTERS.some(([k]) => k === sp.filter) ? String(sp.filter) : "all";
  const items = await listKeepers(q, filter);
  const href = (f: string) => `/keepers?${new URLSearchParams({ ...(q && { q }), ...(f !== "all" && { filter: f }) })}`;
  return (
    <>
      <div className="head">
        <div><h1>별지기</h1><p className="muted">별지기 이름, 번호로 찾을 수 있어요. 쓴 글은 볼 수 없어요.</p></div>
        {operator.role === "owner" && <a href="/keepers/export" className="btn" download>CSV 내보내기</a>}
      </div>
      <div className="toolbar">
        <form className="search" action="/keepers">
          {filter !== "all" && <input type="hidden" name="filter" value={filter} />}
          <input name="q" defaultValue={q} placeholder="별지기 이름 또는 #번호로 찾기" aria-label="별지기 찾기" />
        </form>
        <nav className="tabs" aria-label="거르기">
          {FILTERS.map(([k, label]) => <Link key={k} href={href(k)} aria-current={k === filter ? "true" : undefined}>{label}</Link>)}
        </nav>
      </div>
      <div className="card table-card">
        <table className="table">
          <thead><tr><th>별지기</th><th>번호</th><th>가입</th><th>로그인</th><th>별</th><th>나눈 별</th><th>신고 받음</th><th>코인</th><th>상태</th></tr></thead>
          <tbody>
            {items.length === 0 ? <tr><td colSpan={9} className="muted">찾는 별지기가 없어요.</td></tr> : items.map((k) => (
              <tr key={k.id}>
                <td><Link href={`/keepers/${encodeURIComponent(k.id)}`} className="row-link">{k.nickname ?? <span className="faint">이름 없음</span>}</Link></td>
                <td>{k.no}</td><td>{k.joined_at.slice(0, 10)}</td><td>{PROVIDER_LABEL[k.provider] ?? k.provider}</td>
                <td>{k.stars}</td><td>{k.shared}</td><td>{k.reports}</td><td>{k.coins.toLocaleString("ko-KR")}</td>
                <td><span className={`badge ${k.status === "restricted" ? "badge-hidden" : "badge-done"}`}>{k.status === "restricted" ? "제한" : "정상"}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
