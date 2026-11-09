import { redirect } from "next/navigation";
import { api } from "@/lib/api";
import type { Me } from "@/lib/types";
import { Coin } from "./icons";
import styles from "./Account.module.css";

const PROVIDER: Record<string, string> = { apple: "Apple로 로그인", google: "Google로 로그인", dev: "테스트 계정", invite: "초대 계정" };

// Reads the session: always rendered inside a Suspense boundary (see (app)/layout.tsx).
export async function Account() {
  const me = await api<Me>("/v1/me");
  if (me.needs_consent) redirect("/welcome");
  return (
    <div className={styles.box}>
      <div className={styles.row}>
        <div className={styles.who}>
          <span className="label-m">{me.nickname || "별지기"}</span>
          <span className="caption faint">{PROVIDER[me.provider] ?? me.provider}</span>
        </div>
        <a href="/coins" className={styles.coins} aria-label={`보유 코인 ${me.coins}`}><Coin size={16} />{me.coins.toLocaleString("ko-KR")}</a>
      </div>
      <form action="/auth/logout" method="post"><button className={styles.logout}>로그아웃</button></form>
    </div>
  );
}

export function AccountSkeleton() {
  return <div className={styles.box} aria-hidden="true" style={{ minHeight: 98 }} />;
}
