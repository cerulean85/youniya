import type { ReactNode } from "react";
import styles from "./Status.module.css";

// Figma W-83~W-88 (Mobile 102, 113, 36, 39, 120…). Inside the app (웹 v1.1 · 오류 644:31823, 644:31950): a small
// icon, the title and the cause on the left, the actions in one row, `note` (the server's reason) set off by a rule.
// `full` (signed out: no top bar) keeps the centred column with the orb.
export function StatusScreen({ icon, title, body, note, children, full = false }: { icon: ReactNode; title: string; body: ReactNode; note?: ReactNode; children?: ReactNode; full?: boolean }) {
  return (
    <section className={styles.status} data-full={full || undefined} aria-labelledby="status-title">
      <div className={styles.orb} aria-hidden="true"><span /><i /><b />{icon}</div>
      <h1 id="status-title" className={full ? "h2" : "h1"}>{title}</h1>
      <p className={full ? "body-s muted" : "body-l muted"}>{body}</p>
      {note && <p className={styles.note}>{note}</p>}
      {children && <div className={styles.actions}>{children}</div>}
    </section>
  );
}

/** A link that remembers where it was pressed, so 충전 완료 can go back there (W-84 '하던 곳으로 돌아가기'). */
export { CoinsLink } from "./CoinsLink";
