import type { Metadata } from "next";
import { ComingSoon, PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "별 만들기" };

export default function Page() {
  return (
    <>
      <PageHeader title="별 만들기" />
      <ComingSoon figma="W-11" />
    </>
  );
}
