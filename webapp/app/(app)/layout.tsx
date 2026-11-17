import { Suspense } from "react";
import { Account, AccountSkeleton } from "@/components/Account";
import { FlashServer } from "@/components/FlashServer";
import { TopBar } from "@/components/TopBar";
import styles from "./shell.module.css";

// Every signed-in screen (Figma 웹 v1.1, 2026-11-17): the top bar, then the screen (1440 design width).
// The bar prerenders; the balance and name read the session and stream in.
export default function AppLayout({ children }: LayoutProps<"/">) {
  return (
    <div className={styles.shell}>
      <TopBar account={<Suspense fallback={<AccountSkeleton />}><Account /></Suspense>} />
      <main className={styles.main}>{children}</main>
      <Suspense fallback={null}><FlashServer /></Suspense>
    </div>
  );
}
