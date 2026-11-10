"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import type { AppNotification } from "@/lib/types";
import { loadMore } from "./actions";
import { ago, NotificationRow } from "./Row";
import styles from "./notifications.module.css";

// W-58: scrolling to the end brings the older ones (next_before), until there are none.
export function MoreNotifications({ before: first }: { before: string }) {
  const [items, setItems] = useState<AppNotification[]>([]);
  const [before, setBefore] = useState<string | null>(first);
  const [pending, start] = useTransition();
  const sentinel = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = sentinel.current;
    if (!el || !before) return;
    const io = new IntersectionObserver(([e]) => {
      if (!e.isIntersecting || pending) return;
      start(async () => {
        const r = await loadMore(before);
        setItems((x) => [...x, ...r.items]);
        setBefore(r.next_before);
      });
    }, { rootMargin: "240px" });
    io.observe(el);
    return () => io.disconnect();
  }, [before, pending]);

  const [now] = useState(() => Date.now());
  return (
    <>
      {items.length > 0 && <ul className={styles.list}>{items.map((n) => <NotificationRow key={n.id} n={n} ago={ago(n.created_at, now)} />)}</ul>}
      {before && <div ref={sentinel} className={styles.sentinel} aria-hidden="true">{pending ? "지난 알림을 불러오는 중…" : ""}</div>}
    </>
  );
}
