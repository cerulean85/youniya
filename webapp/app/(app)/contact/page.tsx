import type { Metadata } from "next";
import { ComingSoon, PageHeader } from "@/components/Page";

export const metadata: Metadata = { title: "문의하기" };

export default function Page() {
  return (
    <>
      <PageHeader title="문의하기" sub="내용과 연락 받을 이메일을 남겨 주세요." />
      <ComingSoon figma="W-19" />
    </>
  );
}
