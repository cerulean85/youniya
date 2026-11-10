"use client";

import { useState } from "react";
import { Heart } from "./icons";
import styles from "./CrisisCare.module.css";

// Mobile 37 on the web (C-3): after writing with crisis signals, a full-screen 109 guide that never blocks:
// "괜찮아요, 계속할게요" goes on to the star. The writing is kept as written.
export function CrisisCare() {
  const [open, setOpen] = useState(true);
  if (!open) return null;
  return (
    <div className={styles.overlay} role="dialog" aria-modal="true" aria-labelledby="care-title">
      <div className={styles.hero} aria-hidden="true"><span /><span /><Heart size={28} /></div>
      <h2 id="care-title" className="h2">지금 많이 힘드신가요?</h2>
      <p className="body-m muted">혼자 견디지 않아도 괜찮아요.<br />전문 상담이 24시간 열려 있어요.</p>
      <p className={styles.banner}>자살예방 상담전화 109 (24시간)</p>
      <div className={styles.actions}>
        <a href="tel:109" className="btn btn-primary btn-block">109로 전화하기</a>
        <button type="button" className="btn btn-ghost btn-block" onClick={() => setOpen(false)}>괜찮아요, 계속할게요</button>
      </div>
    </div>
  );
}
