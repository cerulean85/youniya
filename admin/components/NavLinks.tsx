"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { NavItem } from "@/lib/nav";

/** Pending counts beside an item (신고 대기, 새 문의); only when the data is there. */
export type NavCounts = Partial<Record<string, { n: number; hot?: boolean }>>;

export function NavLinks({ items, counts = {} }: { items: NavItem[]; counts?: NavCounts }) {
  const path = usePathname();
  const groups = [...new Set(items.map((n) => n.group))];
  return (
    <nav className="nav">
      {groups.map((g) => (
        <div key={g || "top"} className="nav-group">
          {g && <span className="nav-head">{g}</span>}
          {items.filter((n) => n.group === g).map((n) => {
            const c = counts[n.href];
            return (
              <Link key={n.href} href={n.href} aria-current={path === n.href || path.startsWith(`${n.href}/`) ? "page" : undefined}>
                {n.label}
                {c && c.n > 0 && <span className={`count${c.hot ? " hot" : ""}`} aria-label={`${c.n}건`}>{c.n}</span>}
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );
}
