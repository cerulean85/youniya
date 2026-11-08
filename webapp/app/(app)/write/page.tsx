import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Close } from "@/components/icons";
import { api } from "@/lib/api";
import type { Draft, Me } from "@/lib/types";
import { WriteForm } from "./WriteForm";
import styles from "./write.module.css";

export const metadata: Metadata = { title: "별 만들기" };

// Figma W-11 (별 만들기) with W-23 (분석 중) while a star is made.
export default function WritePage() {
  return (
    <>
      <div className={styles.top}>
        <Link href="/" className={styles.close}><Close size={18} />닫기</Link>
        <span className="label-m">별 만들기</span>
        <span className={styles.spacer} />
      </div>
      <Suspense fallback={<div className={`card ${styles.loading}`} aria-busy="true" />}>
        <Editor />
      </Suspense>
    </>
  );
}

async function Editor() {
  const [draft, me] = await Promise.all([api<Draft>("/v1/drafts/current"), api<Me>("/v1/me")]);
  return <WriteForm draft={draft} freeStarToday={me.free_star_today} coins={me.coins} />;
}
