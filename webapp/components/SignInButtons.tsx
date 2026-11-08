"use client";

import { useSearchParams } from "next/navigation";
import Script from "next/script";
import { useCallback, useEffect, useRef, useState } from "react";
import styles from "./SignInButtons.module.css";

type GoogleId = {
  initialize: (o: { client_id: string; callback: (r: { credential: string }) => void; ux_mode?: string }) => void;
  renderButton: (el: HTMLElement, o: Record<string, unknown>) => void;
};
declare global { interface Window { google?: { accounts: { id: GoogleId } } } }

export function SignInButtons({ googleClientId }: { googleClientId: string }) {
  const box = useRef<HTMLDivElement>(null);
  const params = useSearchParams();
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);
  const error = failed ? "Google로 로그인하지 못했어요. 잠시 뒤에 다시 시도해 주세요."
    : params.get("error") ? "로그인하지 못했어요. 다시 시도해 주세요." : null;
  const nextParam = params.get("next");

  const onGoogle = useCallback(async ({ credential }: { credential: string }) => {
    setBusy(true);
    const r = await fetch("/auth/google", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ credential, next: nextParam }) });
    if (!r.ok) { setBusy(false); setFailed(true); return; }
    window.location.assign((await r.json()).to);
  }, [nextParam]);

  const render = useCallback(() => {
    const id = window.google?.accounts.id;
    if (!id || !box.current) return;
    id.initialize({ client_id: googleClientId, callback: onGoogle });
    id.renderButton(box.current, { theme: "filled_black", size: "large", shape: "rectangular", text: "continue_with", locale: "ko", width: box.current.clientWidth || 384 });
  }, [googleClientId, onGoogle]);

  useEffect(() => { render(); }, [render]);
  const appleHref = nextParam ? `/auth/apple/start?next=${encodeURIComponent(nextParam)}` : "/auth/apple/start";

  return (
    <div className={styles.buttons}>
      <Script src="https://accounts.google.com/gsi/client" strategy="afterInteractive" onReady={render} />
      <a href={appleHref} className={`btn btn-block ${styles.apple}`} aria-disabled={busy}>
        <svg width="16" height="16" viewBox="0 0 814 1000" aria-hidden="true" fill="currentColor"><path d="M788 341c-6 4-108 62-108 190 0 148 130 200 134 201-1 3-21 72-69 142-43 62-87 123-156 123s-87-40-166-40c-77 0-104 41-167 41s-107-57-158-128C39 785 0 664 0 549 0 365 120 267 238 267c63 0 115 41 155 41 38 0 97-44 168-44 27 0 124 3 188 77ZM554 175c30-35 51-84 51-133 0-7-1-14-2-19-48 2-105 32-140 72-27 31-52 80-52 130 0 8 1 15 2 18 3 1 9 1 14 1 43 0 98-29 127-69Z" /></svg>
        Apple로 계속하기
      </a>
      <div ref={box} className={styles.google} aria-busy={busy} />
      {error && <p className="body-s" role="alert">{error}</p>}
    </div>
  );
}
