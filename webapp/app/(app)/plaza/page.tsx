import type { Metadata } from "next";
import { ComingSoon, PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "우주 광장" };

export default function Page() {
  return (
    <>
      <PageHeader title="우주 광장" sub="누군가의 별이에요. 눌러서 한 문장을 읽고, 마음이 닿으면 공명을 남겨 보세요." />
      <ComingSoon figma="W-13" />
    </>
  );
}
