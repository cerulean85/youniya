"use client";

import { useEffect } from "react";
import styles from "./Offline.module.css";

// Figma W-89: the toast a server action left behind (lib/flash); shown once, the cookie cleared at once.
export function FlashShow({ title, sub }: { title: string; sub?: string }) {
  useEffect(() => { document.cookie = "yn_flash=; path=/; max-age=0"; }, []);
  return <Toast title={title} sub={sub} />;
}

/** One toast, title and an optional second line; it fades on its own. */
export function Toast({ title, sub }: { title: string; sub?: string }) {
  return <p className={styles.toast} role="status"><b>{title}</b>{sub && <span>{sub}</span>}</p>;
}
