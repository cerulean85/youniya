import { redirect } from "next/navigation";
import Link from "next/link";
import { api } from "@/lib/api";
import type { Me } from "@/lib/types";
import { ApplySky } from "./ApplySky";
import { Coin, User } from "./icons";
import styles from "./Account.module.css";

// Figma 웹 v1.1 Top Bar · Right: the balance chip (opens 코인) and the 별지기 name (opens 설정).
// Reads the session: always rendered inside a Suspense boundary (see (app)/layout.tsx).
export async function Account() {
  const me = await api<Me>("/v1/me");
  if (me.needs_consent) redirect("/welcome");
  return (
    <>
      <ApplySky sky={me.settings?.sky ?? "violet"} still={Boolean(me.settings?.reduce_animations)} />
      <a href="/coins" className={styles.coins} aria-label={`보유 코인 ${me.coins}`}><Coin size={18} />{me.coins.toLocaleString("ko-KR")}</a>
      <Link href="/settings" className={styles.who} aria-label={`${me.nickname || "별지기"} · 설정`}>
        <User size={18} />
        <span className={styles.name}>{me.nickname || "별지기"}</span>
      </Link>
    </>
  );
}

export function AccountSkeleton() {
  return <span className={styles.skeleton} aria-hidden="true" />;
}
