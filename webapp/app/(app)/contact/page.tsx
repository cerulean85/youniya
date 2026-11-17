import type { Metadata } from "next";
import Link from "next/link";
import { PageHeader } from "@/components/Page";
import { ContactForm } from "./ContactForm";
import styles from "./contact.module.css";

export const metadata: Metadata = { title: "문의하기" };

// W-19 문의하기: kind, the email for the reply, and what happened. Goes to the operators' A-07.
// Figma 웹 v1.1 · 문의 (642:31638): the form on the left; 109 beside it, past a hairline.
export default function Page() {
  return (
    <div className={styles.page}>
      <div className={styles.main}>
        <Link href="/settings#help" className={styles.back}>‹ 설정</Link>
        <PageHeader title="문의하기" sub="궁금한 점이나 불편한 점을 남겨 주세요. 보통 하루 안에 이메일로 답해요." />
        <ContactForm />
      </div>
      <aside className={styles.side} aria-labelledby="crisis-title">
        <h2 id="crisis-title" className="label-m">마음이 많이 힘든 날에는</h2>
        <p className="body-s muted">24시간 상담 전화 109로 연락해 주세요. 문의 답장보다 빠르게 이야기를 들어 줘요.</p>
        <a href="tel:109" className={styles.call}>109 전화하기 ›</a>
      </aside>
    </div>
  );
}
