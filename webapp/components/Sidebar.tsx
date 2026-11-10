import Link from "next/link";
import { Suspense, type ReactNode } from "react";
import { Archive, Bell, Coin, Mail, Moon, Nebula, Settings, Star } from "./icons";
import { UnreadDot } from "./UnreadDot";
import { NavLinks } from "./NavLinks";
import styles from "./Sidebar.module.css";

// Figma: Web/Sidebar. The main tabs of the iOS tab bar plus its drawer menu (2026-11-09: 별자리, no 마음 망원경).
export const MAIN_NAV = [
  { href: "/", label: "오늘", icon: <Moon /> },
  { href: "/constellation", label: "별자리", icon: <Nebula /> },
  { href: "/plaza", label: "우주 광장", icon: <Star /> },
  { href: "/records", label: "기록", icon: <Archive /> },
];
export const MORE_NAV = [
  // The unread dot reads the session, so it streams in on its own.
  // Mobile drawer order (C-11): 별빛 없는 별 first, as a shortcut to the records filtered to them.
  { href: "/records?state=kept", label: "별빛 없는 별", icon: <Archive /> },
  { href: "/notifications", label: "알림", icon: <Bell />, badge: <Suspense fallback={null}><UnreadDot /></Suspense> },
  { href: "/coins", label: "코인", icon: <Coin /> },
  { href: "/settings", label: "설정", icon: <Settings /> },
  { href: "/contact", label: "문의하기", icon: <Mail /> },
];

export function Sidebar({ account }: { account: ReactNode }) {
  return (
    <aside className={styles.sidebar}>
      <Link href="/" className={styles.logo}>
        <Star size={22} className={styles.logoMark} />
        YOUNIYA
      </Link>
      <Link href="/write" className="btn btn-primary btn-block">오늘의 별 만들기</Link>
      {/* usePathname suspends on routes with unknown params (/stars/[id]); the fallback has no highlight. */}
      <Suspense fallback={<NavLinks main={MAIN_NAV} more={MORE_NAV} active={null} />}>
        <NavLinks main={MAIN_NAV} more={MORE_NAV} />
      </Suspense>
      <div className={styles.spacer} />
      {account}
    </aside>
  );
}
