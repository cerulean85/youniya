import type { Metadata } from "next";
import { ComingSoon, PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "코인" };

export default function Page() {
  return (
    <>
      <PageHeader title="코인" sub="필요한 만큼만 충전해요. 기록은 코인 없이도 쓸 수 있어요." />
      <ComingSoon figma="W-18" />
    </>
  );
}
