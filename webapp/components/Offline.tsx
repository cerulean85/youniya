"use client";

import { useEffect, useState } from "react";
import { WifiOff } from "./icons";
import styles from "./Offline.module.css";

/** Whether the browser says it is online, following the online/offline events. */
export function useOnline() {
  const [online, setOnline] = useState(true);
  useEffect(() => {
    const sync = () => setOnline(navigator.onLine);
    const t = setTimeout(sync, 0);
    window.addEventListener("online", sync);
    window.addEventListener("offline", sync);
    return () => { clearTimeout(t); window.removeEventListener("online", sync); window.removeEventListener("offline", sync); };
  }, []);
  return online;
}

// Figma W-103 (Mobile 35 on the web): no full screen; a banner at the bottom while the writing stays put.
export function OfflineBanner({ onRetry }: { onRetry: () => void }) {
  return (
    <div className={styles.banner} role="alert">
      <WifiOff size={18} />
      <b>연결이 잠시 끊겼어요</b>
      <span>쓰던 글은 이 기기에 안전하게 있어요.</span>
      <button type="button" className="btn btn-primary" onClick={onRetry}>다시 시도</button>
    </div>
  );
}

export function FlashToast({ message }: { message: string }) {
  return <p className={styles.toast} role="status">{message}</p>;
}
