"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { drawConstellationCard, type ConstellationCardData } from "@/lib/card-image";
import { ShareCard } from "./ShareCard";
import styles from "./ShareCard.module.css";

// Mobile 08-10 as a web sheet (기획서 23장): the star that fills a month's last slot gets, once its birth is over,
// '{별자리}를 완성했어요' with the card, once per month in this browser.
export function CompleteSheet({ data, monthLabel }: { data: ConstellationCardData; monthLabel: string }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [url, setUrl] = useState<string | null>(null);
  const key = `yn_complete_${data.heading}`;

  useEffect(() => {
    try { if (localStorage.getItem(key)) return; } catch { /* private mode */ }
    let made: string | null = null, gone = false;
    // Wait for the birth (W-102) to be closed first.
    const t = setInterval(() => {
      if (document.querySelector('[aria-label="별 탄생"]')) return;
      clearInterval(t);
      try { localStorage.setItem(key, "1"); } catch { /* private mode */ }
      dialog.current?.showModal();
      drawConstellationCard(data).then((b) => { if (!gone && b) { made = URL.createObjectURL(b); setUrl(made); } }).catch(() => null);
    }, 400);
    return () => { gone = true; clearInterval(t); if (made) URL.revokeObjectURL(made); };
  }, [data, key]);

  return (
    <dialog ref={dialog} className={`card sheet ${styles.dialog}`} aria-labelledby="complete-title">
      <h2 id="complete-title" className="h2" style={{ textAlign: "center" }}>{data.name}자리를 완성했어요</h2>
      <div className={styles.preview}>
        {/* eslint-disable-next-line @next/next/no-img-element -- a blob made in the browser */}
        {url ? <img src={url} alt={`${data.name}자리 카드`} /> : <span className="caption faint">카드를 그리는 중…</span>}
      </div>
      <p className="body-s muted" style={{ textAlign: "center" }}>{monthLabel}에 띄운 별 {data.filled}개가 {data.name}자리를 모두 채웠어요.</p>
      <ShareCard kind="constellation" data={data} label="별자리 카드로 나누기" className="btn btn-primary btn-block" onOpen={() => dialog.current?.close()} />
      <Link href="/constellation" className="btn btn-ghost btn-block">별자리 보기</Link>
    </dialog>
  );
}
