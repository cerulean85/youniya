import type { Metadata } from "next";
import { PageHeader } from "@/components/Page";
import { ContactForm } from "./ContactForm";

export const metadata: Metadata = { title: "문의하기" };

// W-19 문의하기: kind, the email for the reply, and what happened. Goes to the operators' A-07.
export default function Page() {
  return (
    <div className="page-column" style={{ ["--column" as string]: "640px" }}>
      <PageHeader title="문의하기" sub="궁금한 점이나 불편한 점을 남겨 주세요. 보통 하루 안에 이메일로 답해요." />
      <ContactForm />
    </div>
  );
}
