import type { ReactNode } from "react";
import styles from "./Page.module.css";

export function PageHeader({ title, sub, aside }: { title: string; sub?: ReactNode; aside?: ReactNode }) {
  return (
    <header className={styles.header}>
      <div className={styles.titles}>
        {/* Web 시안 v2 tool screens (설정·알림·코인·문의): a 36px serif title, no lead. */}
        <h1 className="v2-tool">{title}</h1>
        {sub && <p className="v2-body">{sub}</p>}
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
