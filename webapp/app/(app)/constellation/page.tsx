import type { Metadata } from "next";
import { ComingSoon, PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "나의 별자리" };

// Figma W-16 (484:13329): the month's constellation, filled with my stars (기획서 16장). Step 3.
export default function ConstellationPage() {
  return (
    <>
      <PageHeader title="나의 별자리" sub="이달의 별자리 자리를 별로 하나씩 채워요." />
      <ComingSoon figma="W-16" />
    </>
  );
}
