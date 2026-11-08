import type { Metadata } from "next";
import { ComingSoon, PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "설정" };

export default function Page() {
  return (
    <>
      <PageHeader title="설정" sub="나에게 맞는 밤하늘 · 필요한 것만 켜 두세요." />
      <ComingSoon figma="W-15" />
    </>
  );
}
