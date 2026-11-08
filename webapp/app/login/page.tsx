import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Lock, Star, StarFilled } from "@/components/icons";
import { SignInButtons } from "@/components/SignInButtons";
import { DEV_LOGIN, GOOGLE_CLIENT_ID } from "@/lib/config";
import styles from "./login.module.css";

export const metadata: Metadata = { title: "로그인" };

const SITE = "https://youniya.dycdyp.com";

// Figma W-20. Apple: redirect flow (/auth/apple/start). Google: Google Identity Services button.
export default function LoginPage() {
  return (
    <div className={styles.page}>
      <section className={styles.brand}>
        <Link href={SITE} className={styles.logo}><Star size={22} className={styles.mark} />YOUNIYA</Link>
        <div className={styles.brandBody}>
          <div className={styles.orb} aria-hidden="true"><StarFilled size={56} /></div>
          <h1 className="display">텍스트로 시각화한<br />우리 모두의 우주</h1>
          <p className="body-l muted">하루를 적으면 별이 되고, 별이 모이면 나만의 성운이 돼요.</p>
        </div>
        <nav className={styles.links} aria-label="정책">
          <a href={`${SITE}/terms`}>이용약관</a>
          <a href={`${SITE}/privacy`}>개인정보 처리방침</a>
          <a href={`${SITE}/support`}>문의하기</a>
        </nav>
      </section>
      <section className={styles.pane}>
        <div className={`card ${styles.card}`}>
          <h2 className="h1">오늘의 마음을<br />별로 빚어볼까요</h2>
          <p className={`body-m muted ${styles.note}`}><Lock size={16} />당신만 볼 수 있는 고요한 밤하늘이에요. 쓴 글은 암호화되어 안전하게 보관돼요.</p>
          <Suspense fallback={<div style={{ minHeight: 112, width: "100%" }} />}>
            <SignInButtons googleClientId={GOOGLE_CLIENT_ID} />
          </Suspense>
          <p className="caption faint">처음이라면 다음 화면에서 이용약관과 개인정보 처리 동의를 받아요.</p>
          {DEV_LOGIN && (
            <form action="/auth/dev" method="post" className={styles.dev}>
              <input name="name" placeholder="테스트 계정 이름" defaultValue="web-dev" aria-label="테스트 계정 이름" />
              <button className="btn btn-secondary">테스트 로그인</button>
            </form>
          )}
        </div>
      </section>
    </div>
  );
}
