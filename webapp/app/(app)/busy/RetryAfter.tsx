"use client";

import { useEffect, useState } from "react";

export function RetryAfter({ seconds, back }: { seconds: number; back: string }) {
  const [left, setLeft] = useState(seconds);
  useEffect(() => {
    if (left <= 0) return;
    const t = setTimeout(() => setLeft((n) => n - 1), 1000);
    return () => clearTimeout(t);
  }, [left]);
  const label = left <= 0 ? "다시 시도하기" : left >= 60 ? `${Math.ceil(left / 60)}분 뒤에 다시 시도` : `${left}초 뒤에 다시 시도`;
  return <a href={back} className="btn btn-primary btn-block" aria-disabled={left > 0} onClick={(e) => { if (left > 0) e.preventDefault(); }} style={left > 0 ? { opacity: 0.55, pointerEvents: "none" } : undefined}>{label}</a>;
}
