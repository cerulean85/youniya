import { Suspense } from "react";
import { Account, AccountSkeleton } from "@/components/Account";
import { FlashServer } from "@/components/FlashServer";
import { Sidebar } from "@/components/Sidebar";
import styles from "./shell.module.css";

// Every signed-in screen: the Figma Web/Sidebar on the left, the screen on the right (1440 design width).
// The sidebar frame prerenders; the account box reads the session and streams in.
export default function AppLayout({ children }: LayoutProps<"/">) {
  return (
    <div className={styles.shell}>
      <Sidebar account={<Suspense fallback={<AccountSkeleton />}><Account /></Suspense>} />
      <main className={styles.main}>{children}</main>
      <Suspense fallback={null}><FlashServer /></Suspense>
    </div>
  );
}
