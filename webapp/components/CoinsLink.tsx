"use client";

export function CoinsLink({ className, children }: { className?: string; children: React.ReactNode }) {
  return (
    <a href="/coins" className={className}
      onClick={(e) => { e.currentTarget.href = `/coins?from=${encodeURIComponent(location.pathname + location.search)}`; }}>
      {children}
    </a>
  );
}
