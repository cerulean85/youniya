import Link from "next/link";
import { Suspense, type ReactNode } from "react";
import { Archive, Coin, Mail, Moon, Nebula, Settings, Star, Telescope } from "./icons";
import { NavLinks } from "./NavLinks";
import styles from "./Sidebar.module.css";

// Figma: Web/Sidebar (W-10 to W-19). The main tabs of the iOS Tab Bar v2 plus its drawer menu.
export const MAIN_NAV = [
  { href: "/", label: "나의 밤하늘", icon: <Moon /> },
  { href: "/nebula", label: "성운", icon: <Nebula /> },
  { href: "/plaza", label: "우주 광장", icon: <Star /> },
  { href: "/records", label: "기록", icon: <Archive /> },
];
export const MORE_NAV = [
  { href: "/telescope", label: "마음 망원경", icon: <Telescope /> },
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
