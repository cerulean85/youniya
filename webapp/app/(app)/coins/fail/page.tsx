import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Lock } from "@/components/icons";
import { StatusScreen } from "@/components/Status";

export const metadata: Metadata = { title: "결제가 끝나지 않았어요" };

// The server's confirm errors, said plainly. Toss's own failures keep Toss's message.
const KNOWN: Record<string, string> = {
  amount_mismatch: "결제 금액이 주문과 달라 결제를 멈췄어요. 돈은 빠져나가지 않았어요.",
  order_expired: "주문이 만료됐어요(30분). 다시 충전해 주세요.",
  order_not_found: "주문을 찾지 못했어요. 다시 충전해 주세요.",
  order_used: "이미 다른 결제로 처리된 주문이에요.",
  payment_key_used: "이미 사용된 결제예요. 다시 충전해 주세요.",
  order_canceled: "취소된 주문이에요.",
  order_in_progress: "결제를 처리하는 중이에요. 잠시 뒤 코인 내역을 확인해 주세요.",
  payment_unconfirmed: "결제 결과를 아직 받지 못했어요. 잠시 뒤 코인 내역을 확인하고, 코인이 없으면 문의해 주세요.",
};
const safe = (v: unknown) => (typeof v === "string" && v.startsWith("/") && !v.startsWith("//") ? v : null);

// Figma W-86 (Mobile 103): Toss's failUrl, or a confirmation that didn't go through.
export default function FailPage({ searchParams }: PageProps<"/coins/fail">) {
  return <Suspense fallback={null}><Reason searchParams={searchParams} /></Suspense>;
}

async function Reason({ searchParams }: Pick<PageProps<"/coins/fail">, "searchParams">) {
  const sp = await searchParams;
  const code = typeof sp.code === "string" ? sp.code.slice(0, 40) : "";
  const cancel = code === "PAY_PROCESS_CANCELED" || code === "USER_CANCEL";
  const detail = cancel ? null : KNOWN[code] ?? (typeof sp.message === "string" ? sp.message.slice(0, 200) : null);
  const from = safe(sp.from);
  return (
    <StatusScreen icon={<Lock size={22} />} title="결제가 끝나지 않았어요"
      body={<>코인은 차감되거나 지급되지 않았어요.{detail && <><br />{detail}</>}</>}>
      <Link href={from ? `/coins?from=${encodeURIComponent(from)}` : "/coins"} className="btn btn-primary btn-block">다시 결제하기</Link>
      <Link href={from ?? "/"} className="btn btn-ghost btn-block">닫기</Link>
      {!cancel && code && <p className="caption faint">돈이 빠져나갔는데 코인이 들어오지 않았다면 <Link href="/contact">문의하기</Link>로 알려 주세요 (코드 {code}).</p>}
    </StatusScreen>
  );
}
