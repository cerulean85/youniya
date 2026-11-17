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
        {operator.role === "owner" && <a href="/keepers/export" className="btn-text" download>CSV 내보내기</a>}
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
      {items.length === 0 ? (
        <div className="empty">
          <h2>찾는 별지기가 없어요.</h2>
          {(q || filter !== "all") && <Link className="accent" href="/keepers">전체 별지기 보기 ›</Link>}
        </div>
      ) : (
        <table className="table">
          <thead><tr><th>별지기</th><th>번호</th><th>가입</th><th>로그인</th><th className="num">별</th><th className="num">나눈 별</th><th className="num">신고 받음</th><th className="num">코인</th><th>상태</th></tr></thead>
          <tbody>
            {items.map((k) => (
              <tr key={k.id}>
                <td><Link href={`/keepers/${encodeURIComponent(k.id)}`} className="row-link">{k.nickname ?? <span className="faint">이름 없음</span>}</Link></td>
                <td>{k.no}</td><td>{k.joined_at.slice(0, 10)}</td><td>{PROVIDER_LABEL[k.provider] ?? k.provider}</td>
                <td className="num">{k.stars}</td><td className="num">{k.shared}</td><td className="num">{k.reports}</td><td className="num">{k.coins.toLocaleString("ko-KR")}</td>
                <td><span className={`badge ${k.status === "restricted" ? "badge-pending" : "badge-muted"}`}>{k.status === "restricted" ? `제한${k.restricted_until ? ` · ${k.restricted_until.slice(5, 10)}까지` : ""}` : "정상"}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  );
}
