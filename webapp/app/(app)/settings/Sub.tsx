import { PageHeader } from "@/components/Page";
import styles from "./settings.module.css";

export const GROUPS = [["account", "계정"], ["screen", "화면과 움직임"], ["alerts", "알림"], ["plaza", "우주 광장"], ["data", "데이터"], ["help", "도움"]] as const;
export type Group = (typeof GROUPS)[number][0];

// Figma 웹 v1.1 설정 세부 (W1.1-17~24): the same group index as 설정, its group marked, the page beside it.
export function Sub({ group, children }: { group: Group; children: React.ReactNode }) {
  return (
    <div className={styles.split}>
      <nav className={styles.toc} aria-label="설정 목차">
        <PageHeader title="설정" />
        <ul>{GROUPS.map(([id, label]) => <li key={id}><a href={`/settings#${id}`} aria-current={id === group ? "true" : undefined}>{label}</a></li>)}</ul>
      </nav>
      <div className={styles.sub}>{children}</div>
    </div>
  );
}
