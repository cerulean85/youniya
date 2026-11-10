import type { ReactNode } from "react";
import styles from "./Status.module.css";

// Figma W-83~W-88 (Mobile 102, 113, 36, 39, 120…): one centred column with an orb, a title, a line and actions.
export function StatusScreen({ icon, title, body, children, full = false }: { icon: ReactNode; title: string; body: ReactNode; children?: ReactNode; full?: boolean }) {
  return (
    <section className={styles.status} data-full={full || undefined} aria-labelledby="status-title">
      <div className={styles.orb} aria-hidden="true"><span /><i /><b />{icon}</div>
      <h1 id="status-title" className="h2">{title}</h1>
      <p className="body-s muted">{body}</p>
      {children && <div className={styles.actions}>{children}</div>}
    </section>
  );
}

/** A link that remembers where it was pressed, so 충전 완료 can go back there (W-84 '하던 곳으로 돌아가기'). */
export { CoinsLink } from "./CoinsLink";
