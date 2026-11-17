"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import styles from "./TopBar.module.css";

type Item = { href: string; label: string };

function isActive(href: string, path: string | null) {
  if (path === null) return false;
  if (href === "/") return path === "/" || path === "/write";
  // 웹 v1.1: a star opens under 기록 (its back link goes there).
  if (href === "/records") return path.startsWith("/records") || path.startsWith("/stars");
  return path === href || path.startsWith(`${href}/`);
}

/** `active={null}` renders without a highlight (the Suspense fallback). */
export function NavLinks({ items, active }: { items: Item[]; active?: null }) {
  return active === null ? <Links items={items} path={null} /> : <Current items={items} />;
}

function Current({ items }: { items: Item[] }) {
  return <Links items={items} path={usePathname()} />;
}

function Links({ items, path }: { items: Item[]; path: string | null }) {
  return (
    <nav aria-label="주요 메뉴" className={styles.tabs}>
      {items.map((it) => (
        <Link key={it.href} href={it.href} className={styles.tab} aria-current={isActive(it.href, path) ? "page" : undefined}>{it.label}</Link>
      ))}
    </nav>
  );
}
