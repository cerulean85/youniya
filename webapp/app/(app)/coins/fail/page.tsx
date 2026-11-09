import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "결제하지 못했어요" };

// The server's confirm errors, said plainly. Toss's own failures keep Toss's message.
const KNOWN: Record<string, string> = {
  amount_mismatch: "결제 금액이 주문과 달라 결제를 멈췄어요. 돈은 빠져나가지 않았어요.",
  order_expired: "주문이 만료됐어요(30분). 다시 충전해 주세요.",
  order_not_found: "주문을 찾지 못했어요. 다시 충전해 주세요.",
  order_used: "이미 다른 결제로 처리된 주문이에요.",
  order_canceled: "취소된 주문이에요.",
  order_in_progress: "결제를 처리하는 중이에요. 잠시 뒤 코인 내역을 확인해 주세요.",
  payment_unconfirmed: "결제 결과를 아직 받지 못했어요. 잠시 뒤 코인 내역을 확인하고, 코인이 없으면 문의해 주세요.",
};

// Toss's failUrl, or a confirmation that didn't go through. Nothing was charged unless Toss says otherwise.
export default function FailPage({ searchParams }: PageProps<"/coins/fail">) {
  return (
    <>
      <PageHeader title="결제하지 못했어요" />
      <Suspense fallback={null}><Reason searchParams={searchParams} /></Suspense>
    </>
  );
}

async function Reason({ searchParams }: Pick<PageProps<"/coins/fail">, "searchParams">) {
  const sp = await searchParams;
  const cancel = sp.code === "PAY_PROCESS_CANCELED" || sp.code === "USER_CANCEL";
  const code = typeof sp.code === "string" ? sp.code : "";
  const message = KNOWN[code] ?? (typeof sp.message === "string" ? sp.message.slice(0, 200) : null);
  return (
    <div className="card" style={{ maxWidth: 520, padding: 28, borderRadius: 20, display: "flex", flexDirection: "column", gap: 12 }}>
      <p className="body-m">{cancel ? "결제를 취소했어요. 코인은 그대로예요." : message ?? "결제 중에 문제가 생겼어요."}</p>
      {!cancel && <p className="caption faint">돈이 빠져나갔는데 코인이 들어오지 않았다면 문의하기로 알려 주세요{typeof sp.code === "string" ? ` (코드 ${sp.code.slice(0, 40)})` : ""}.</p>}
      <div style={{ display: "flex", gap: 8 }}>
        <Link href="/coins" className="btn btn-primary">코인으로 돌아가기</Link>
        {!cancel && <Link href="/contact" className="btn btn-ghost">문의하기</Link>}
      </div>
    </div>
  );
}
