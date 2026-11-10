"use client";

import { useEffect } from "react";
import type { Sky } from "@/lib/types";

/** Puts the account's 우주의 색 on <html data-sky> and remembers it for the next first paint. */
export function ApplySky({ sky }: { sky: Sky }) {
  useEffect(() => {
    const root = document.documentElement;
    if (sky === "violet") delete root.dataset.sky;
    else root.dataset.sky = sky;
    try { localStorage.setItem("yn_sky", sky); } catch { /* private mode */ }
  }, [sky]);
  return null;
}
