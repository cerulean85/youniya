import { Sidebar } from "@/components/Sidebar";
import styles from "./shell.module.css";

// Every signed-in screen: the Figma Web/Sidebar on the left, the screen on the right (1440 design width).
export default function AppLayout({ children }: LayoutProps<"/">) {
  return (
    <div className={styles.shell}>
      <Sidebar account={<div className={styles.accountSlot} />} />
      <main className={styles.main}>{children}</main>
    </div>
  );
}
