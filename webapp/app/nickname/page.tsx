import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { NicknameForm } from "@/components/NicknameForm";
import { Star, StarFilled } from "@/components/icons";
import styles from "../login/login.module.css";

export const metadata: Metadata = { title: "별지기 이름 정하기" };

const SITE = "https://youniya.dycdyp.com";

// Figma W-49 (기획서 15.1): after the consent step, and for people who signed up before names, before the plaza.
export default function NicknamePage({ searchParams }: PageProps<"/nickname">) {
  return (
    <div className={styles.page}>
      <section className={styles.brand}>
        <Link href="/" className={styles.logo}><Star size={22} className={styles.mark} />YOUNIYA</Link>
        <div className={styles.brandBody}>
          <div className={styles.orb} aria-hidden="true"><StarFilled size={56} /></div>
          <h1 className="display">텍스트로 시각화한<br />우리 모두의 우주</h1>
          <p className="body-l muted">하루를 적으면 별이 되고, 한 달이 모이면 나만의 별자리가 돼요.</p>
        </div>
        <nav className={styles.links} aria-label="정책">
          <a href={`${SITE}/terms`}>이용약관</a>
          <a href={`${SITE}/privacy`}>개인정보 처리방침</a>
          <a href={`${SITE}/support`}>문의하기</a>
        </nav>
      </section>
      <section className={styles.pane}>
        <div className={`card ${styles.card}`} style={{ alignItems: "stretch", textAlign: "left" }}>
          <h2 className="h1">별지기 이름을 정해 주세요</h2>
          <p className="body-s muted">우주 광장에 별을 나누면 이 이름이 함께 보여요. 내가 건넨 별빛 한 줄에도 이 이름이 보여요.</p>
          <Suspense><Form searchParams={searchParams} /></Suspense>
        </div>
      </section>
    </div>
  );
}

async function Form({ searchParams }: Pick<PageProps<"/nickname">, "searchParams">) {
  const sp = await searchParams;
  const next = typeof sp.next === "string" && sp.next.startsWith("/") && !sp.next.startsWith("//") ? sp.next : "/";
  return <NicknameForm next={next} />;
}
