"use client";

import Link from "next/link";
import { useEffect, useRef } from "react";
import styles from "./Restricted.module.css";

/** Mobile 09-6 / 09-7 (web: top of W-44): plaza use paused by an operator. `open` shows the explanation at once. */
export function RestrictedBanner({ until, open }: { until: string; open?: boolean }) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => { if (open) dialog.current?.showModal(); }, [open]);
  const day = new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", month: "long", day: "numeric" }).format(new Date(until));
  // "11월 16일 오후 10시까지" (the minute only when it isn't on the hour).
  const t = new Date(until), parts = new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", hour: "numeric", minute: "2-digit", hour12: true }).formatToParts(t);
  const get = (k: string) => parts.find((p) => p.type === k)?.value ?? "";
  const until_ = `${day} ${get("dayPeriod")} ${get("hour")}시${get("minute") !== "00" ? ` ${Number(get("minute"))}분` : ""}까지`;
  return (
    <>
      <div className={styles.banner} role="status">
        <div>
          <b>광장 이용이 {day}까지 멈춰요</b>
          <p>별을 나누거나 공명·곁에 두기·별빛 한 줄을 남길 수 없어요. 내 기록과 별은 그대로이고, 다른 별은 계속 읽을 수 있어요.</p>
        </div>
        <button type="button" onClick={() => dialog.current?.showModal()}>자세히 ›</button>
      </div>
      <dialog ref={dialog} className={`card ${styles.dialog}`} aria-labelledby="restricted-title">
        {/* Figma W-61 */}
        <h2 id="restricted-title" className="h2">광장 이용이 잠시 멈춰 있어요</h2>
        <p className="body-s muted">{until_} 별을 나누거나 공명·곁에 두기·별빛 한 줄을 남길 수 없어요. 신고가 확인되어 운영자가 정한 조치예요.<br />내 기록과 별은 그대로이고, 광장의 다른 별은 계속 읽을 수 있어요.</p>
        <button type="button" className="btn btn-primary btn-block" onClick={() => dialog.current?.close()}>확인</button>
        <Link href="/contact" className="btn btn-ghost">문의하기</Link>
      </dialog>
    </>
  );
}

/** Mobile 04-1 (web: top of W-10): an operator asked for a new 별지기 이름. */
export function RenameBanner() {
  return (
    <Link href="/settings?rename=1" className={styles.banner}>
      <div>
        <b>별지기 이름을 바꿔 주세요</b>
        <p>운영자 요청이 있어요. 이름을 바꾸기 전까지는 우주 광장에 새로 별을 나눌 수 없어요. 30일 제한 없이 바로 바꿀 수 있어요.</p>
      </div>
      <span>바꾸기 ›</span>
    </Link>
  );
}
