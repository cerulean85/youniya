import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import Link from "next/link";
import { Stat } from "@/components/Stat";
import { getLedger } from "@/lib/api";
import { monthLabel, num, thisMonth, won } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import type { LedgerKind } from "@/lib/types";

export const metadata: Metadata = { title: "코인·결제" };

const KIND: Record<LedgerKind, [string, string]> = { charge: ["badge-done", "충전"], use: ["badge-muted", "사용"], refund: ["badge-hidden", "환불"], grant: ["badge-info", "지급"], revoke: ["badge-hidden", "회수"] };
const when = (iso: string) => new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date(iso));

// Figma A-08 (owners): App Store and web (Toss) payments in one ledger.
export default async function CoinsPage({ searchParams }: PageProps<"/coins">) {
  await requireOperator(["owner"]);
  const wait = notConnected("owner", "코인·결제");
  if (wait) return wait;
  const sp = await searchParams;
  const month = typeof sp.month === "string" && /^\d{4}-\d{2}$/.test(sp.month) ? sp.month : thisMonth();
  const l = await getLedger(month);
  const s = l.summary;
  return (
    <>
      <div className="head">
        <div><h1>코인·결제</h1><p className="muted">App Store 결제와 웹 결제(Toss)를 함께 보여 줘요. 금액은 상품 가격으로 추정한 값이에요.</p></div>
        <span className="btn" aria-label="기간">기간: {monthLabel(month)}</span>
      </div>
      <div className="stats">
        <Stat label="충전" value={won(s.charge_krw)} sub={`${num(s.charge_count)}건`} />
        <Stat label="환불 회수" value={won(s.refund_krw)} tone="red" sub={`${s.refund_count}건`} />
        {s.usage_share ? <Stat label="코인 사용" value={`별빛 받기 ${s.usage_share.starlight}%`} sub={`망원경 ${s.usage_share.telescope}%`} />
          : <Stat label="코인 사용" value={`${num(Math.abs(s.spend_coins ?? 0))}코인`} />}
        {s.free_used ? <Stat label="무료 몫 사용" value={`별빛 받기 ${num(s.free_used.starlight)}`} sub={`망원경 ${num(s.free_used.telescope)}`} />
          : <Stat label="운영자 지급" value={`${num(s.grant_coins ?? 0)}코인`} />}
      </div>
      <div className="card table-card">
        <table className="table">
          <thead><tr><th>시각</th><th>별지기</th><th>종류</th><th>내용</th><th>코인</th><th>금액</th><th>거래번호</th></tr></thead>
          <tbody>
            {l.items.map((x, i) => (
              <tr key={i}>
                <td>{when(x.at)}</td>
                <td>{x.keeper.id ? <Link href={`/keepers/${encodeURIComponent(x.keeper.id)}`}>{x.keeper.nickname ?? x.keeper.no}</Link>
                  : x.keeper.no.startsWith("#") ? <Link href={`/keepers?q=${encodeURIComponent(x.keeper.no)}`}>{x.keeper.no}</Link>
                  : <span className="faint">{x.keeper.no}</span>}</td>
                <td><span className={`badge ${(KIND[x.kind] ?? KIND.use)[0]}`}>{(KIND[x.kind] ?? KIND.use)[1]}</span>{x.channel === "admin" && x.kind === "refund" ? <span className="faint"> · 운영자</span> : null}</td>
                <td>{x.detail}</td>
                <td>{x.coins > 0 ? `+${num(x.coins)}` : `−${num(-x.coins)}`}</td>
                <td>{(x.amount_krw ?? x.krw_estimate) != null ? won((x.amount_krw ?? x.krw_estimate)!) : "—"}</td>
                <td>{x.reference ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
