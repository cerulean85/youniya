import type { Metadata } from "next";
import { PageHeader } from "@/components/Page";
import { ContactForm } from "./ContactForm";

export const metadata: Metadata = { title: "문의하기" };

// W-19 문의하기: kind, the email for the reply, and what happened. Goes to the operators' A-07.
export default function Page() {
  return (
    <div className="page-column" style={{ ["--column" as string]: "640px" }}>
      <PageHeader title="문의하기" sub="내용과 연락 받을 이메일을 남겨 주세요." />
      <ContactForm />
    </div>
  );
}
