import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Check } from "@/components/icons";
import { StatusScreen } from "@/components/Status";
import { api } from "@/lib/api";
import type { CoinsInfo } from "@/lib/types";

export const metadata: Metadata = { title: "충전이 끝났어요" };

const safe = (v: unknown) => (typeof v === "string" && v.startsWith("/") && !v.startsWith("//") && !v.startsWith("/coins") ? v : null);

// Figma W-84 (Mobile 102): back to the writing that needed the coins.
export default function DonePage({ searchParams }: PageProps<"/coins/done">) {
  return <Suspense fallback={null}><Done searchParams={searchParams} /></Suspense>;
}

async function Done({ searchParams }: Pick<PageProps<"/coins/done">, "searchParams">) {
  const [sp, coins] = await Promise.all([searchParams, api<CoinsInfo>("/v1/coins")]);
  const added = Number(sp.added) || 0;
  const from = safe(sp.from);
  return (
    <StatusScreen icon={<Check size={22} />} title="충전이 끝났어요"
      body={`${added ? `코인 ${added.toLocaleString("ko-KR")}개가 들어왔어요. ` : ""}지금 코인은 ${coins.coins.toLocaleString("ko-KR")}개예요.`}>
      <Link href={from ?? "/"} className="btn btn-primary btn-block">{from ? "하던 곳으로 돌아가기" : "오늘로 돌아가기"}</Link>
      <Link href="/coins#history" className="btn btn-ghost btn-block">코인 사용 내역 보기</Link>
    </StatusScreen>
  );
}
