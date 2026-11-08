import type { Metadata } from "next";
import { ComingSoon, PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "나의 성운" };

export default function Page() {
  return (
    <>
      <PageHeader title="나의 성운" />
      <ComingSoon figma="W-16" />
    </>
  );
}
