import { redirect } from "next/navigation";
import { api } from "@/lib/api";
import type { Me } from "@/lib/types";
import { ApplySky } from "./ApplySky";
import { LogoutButton } from "./LogoutButton";
import Link from "next/link";
import { Coin, User } from "./icons";
import styles from "./Account.module.css";

const PROVIDER: Record<string, string> = { apple: "Apple로 로그인", google: "Google로 로그인", dev: "테스트 계정", invite: "초대 계정" };

// Reads the session: always rendered inside a Suspense boundary (see (app)/layout.tsx).
export async function Account() {
  const me = await api<Me>("/v1/me");
  if (me.needs_consent) redirect("/welcome");
  return (
    <div className={styles.box}>
      <ApplySky sky={me.settings?.sky ?? "violet"} still={Boolean(me.settings?.reduce_animations)} />
      <div className={styles.row}>
        {/* Web/Sidebar 359:177: the person icon, like the app drawer's profile row; opens 설정 › 계정. */}
        <Link href="/settings" className={styles.who}>
          <User size={18} />
          <span className={styles.whoText}>
            <span className="label-m">{me.nickname || "별지기"}</span>
            <span className="caption faint">{PROVIDER[me.provider] ?? me.provider}</span>
          </span>
        </Link>
        <a href="/coins" className={styles.coins} aria-label={`보유 코인 ${me.coins}`}><Coin size={16} />{me.coins.toLocaleString("ko-KR")}</a>
      </div>
      <LogoutButton className={styles.logout}>로그아웃</LogoutButton>
    </div>
  );
}

export function AccountSkeleton() {
  return <div className={styles.box} aria-hidden="true" style={{ minHeight: 98 }} />;
}
