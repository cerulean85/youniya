import type { ReactNode } from "react";
import styles from "./Page.module.css";

export function PageHeader({ title, sub, aside }: { title: string; sub?: ReactNode; aside?: ReactNode }) {
  return (
    <header className={styles.header}>
      <div className={styles.titles}>
        {/* 웹 v1.1 tool screens (알림·코인·설정·문의): the 28px serif title, a quiet line under it. */}
        <h1 className="h1">{title}</h1>
        {sub && <p className="body-m muted">{sub}</p>}
      </div>
      {aside}
    </header>
  );
}

/** A screen that is designed (Figma Web page) but not built yet. */
export function ComingSoon({ figma }: { figma: string }) {
  return (
    <div className={`card ${styles.soon}`}>
      <p className="h3">곧 열려요</p>
      <p className="body-m muted">이 화면은 디자인({figma})까지 마쳤고, 지금 만들고 있어요.</p>
    </div>
  );
}
