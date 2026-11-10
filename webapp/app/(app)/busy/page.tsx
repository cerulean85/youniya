import type { Metadata } from "next";
import { Suspense } from "react";
import { Moon } from "@/components/icons";
import { StatusScreen } from "@/components/Status";
import { RetryAfter } from "./RetryAfter";

export const metadata: Metadata = { title: "잠시 숨을 고르고 있어요" };

// Figma W-88 (Mobile 120): 429 from the API. Nothing was lost or charged; try again after retry_after.
export default function BusyPage({ searchParams }: PageProps<"/busy">) {
  return (
    <StatusScreen icon={<Moon size={22} />} title="잠시 숨을 고르고 있어요"
      body="요청이 한꺼번에 몰렸어요. 쓰던 글은 그대로 있고 코인도 차감되지 않았어요. 조금 뒤에 다시 시도해 주세요.">
      <Suspense fallback={null}><Retry searchParams={searchParams} /></Suspense>
    </StatusScreen>
  );
}

async function Retry({ searchParams }: Pick<PageProps<"/busy">, "searchParams">) {
  const sp = await searchParams;
  const back = typeof sp.back === "string" && sp.back.startsWith("/") && !sp.back.startsWith("//") ? sp.back : "/";
  return <RetryAfter seconds={Math.min(3600, Math.max(0, Number(sp.after) || 0))} back={back} />;
}
