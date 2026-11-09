import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "결제하지 못했어요" };

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
  const message = typeof sp.message === "string" ? sp.message.slice(0, 200) : null;
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
