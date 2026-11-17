import Link from "next/link";
import { Suspense, type ReactNode } from "react";
import { Bell, Star } from "./icons";
import { UnreadDot } from "./UnreadDot";
import { NavLinks } from "./NavLinks";
import styles from "./TopBar.module.css";

// Figma 웹 v1.1 Top Bar (633:30937): the four main tabs on the left, 알림 · 코인 · 계정 on the right.
// 설정 and 문의 open from the account name (설정 › 도움 holds 문의하기 and 로그아웃).
export const MAIN_NAV = [
  { href: "/", label: "오늘" },
  { href: "/constellation", label: "별자리" },
  { href: "/plaza", label: "우주 광장" },
  { href: "/records", label: "기록" },
];

export function TopBar({ account }: { account: ReactNode }) {
  return (
    <header className={styles.bar}>
      <div className={styles.left}>
        <Link href="/" className={styles.logo}>
          <Star size={20} className={styles.logoMark} />
          YOUNIYA
        </Link>
        {/* usePathname suspends on routes with unknown params (/stars/[id]); the fallback has no highlight. */}
        <Suspense fallback={<NavLinks items={MAIN_NAV} active={null} />}>
          <NavLinks items={MAIN_NAV} />
        </Suspense>
      </div>
      <div className={styles.right}>
        <Link href="/notifications" className={styles.bell} aria-label="알림">
          <Bell size={20} />
          {/* The unread dot reads the session, so it streams in on its own. */}
          <Suspense fallback={null}><UnreadDot /></Suspense>
        </Link>
        {account}
      </div>
    </header>
  );
}
