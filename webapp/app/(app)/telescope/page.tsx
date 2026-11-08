import type { Metadata } from "next";
import { ComingSoon, PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "마음 망원경" };

export default function Page() {
  return (
    <>
      <PageHeader title="마음 망원경" sub="별 하나를 세 가지 렌즈로 비춰 봐요." />
      <ComingSoon figma="W-17" />
    </>
  );
}
