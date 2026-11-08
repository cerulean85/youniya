import type { Metadata } from "next";
import { ComingSoon, PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "기록" };

export default function Page() {
  return (
    <>
      <PageHeader title="기록" />
      <ComingSoon figma="W-14" />
    </>
  );
}
