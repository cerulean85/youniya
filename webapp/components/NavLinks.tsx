"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import styles from "./Sidebar.module.css";

type Item = { href: string; label: string; icon: ReactNode; badge?: ReactNode };

function isActive(href: string, path: string | null) {
  if (path === null) return false;
  if (href === "/") return path === "/" || path.startsWith("/stars");
  return path === href || path.startsWith(`${href}/`);
}

function Group({ items, path }: { items: Item[]; path: string | null }) {
  return (
    <>
      {items.map((it) => {
        const on = isActive(it.href, path);
        return (
          <Link key={it.href} href={it.href} className={styles.item} aria-current={on ? "page" : undefined}>
            <span className={styles.icon}>{it.icon}</span>
            {it.label}
            {on ? <span className={styles.dot} aria-hidden="true" /> : it.badge}
          </Link>
        );
      })}
    </>
  );
}

/** `active={null}` renders without a highlight (the Suspense fallback). */
export function NavLinks({ main, more, active }: { main: Item[]; more: Item[]; active?: null }) {
  return active === null ? <Links main={main} more={more} path={null} /> : <Current main={main} more={more} />;
}

function Current({ main, more }: { main: Item[]; more: Item[] }) {
  return <Links main={main} more={more} path={usePathname()} />;
}

function Links({ main, more, path }: { main: Item[]; more: Item[]; path: string | null }) {
  return (
    <nav aria-label="주요 메뉴" className={styles.nav}>
      <div className={styles.group}><Group items={main} path={path} /></div>
      <hr className={styles.divider} />
      <div className={styles.group}>
        <span className={styles.groupLabel}>더 보기</span>
        <Group items={more} path={path} />
      </div>
    </nav>
  );
}
