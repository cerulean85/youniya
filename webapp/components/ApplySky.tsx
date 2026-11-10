"use client";

import { useEffect } from "react";
import type { Sky } from "@/lib/types";

/** Puts the account's 우주의 색 on <html data-sky> (and 애니메이션 줄이기 on data-motion) and remembers it for the next first paint. */
export function ApplySky({ sky, still = false }: { sky: Sky; still?: boolean }) {
  useEffect(() => {
    const root = document.documentElement;
    if (still) root.dataset.motion = "reduce";
    else delete root.dataset.motion;
    if (sky === "violet") delete root.dataset.sky;
    else root.dataset.sky = sky;
    try { localStorage.setItem("yn_sky", sky); localStorage.setItem("yn_motion", still ? "reduce" : ""); } catch { /* private mode */ }
  }, [sky, still]);
  return null;
}
