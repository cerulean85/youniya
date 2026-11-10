import type { Metadata } from "next";
import { Suspense } from "react";
import { api } from "@/lib/api";
import type { Me } from "@/lib/types";
import { Back } from "../Back";
import { SkyCards } from "../SettingsControls";
import styles from "../settings.module.css";

export const metadata: Metadata = { title: "우주의 색" };

// Figma W-90 (iOS 68, 기획서 14.7).
export default function SkyPage() {
  return (
    <div className={styles.page}>
      <Back />
      <h1 className="h1">어떤 밤하늘이<br />편안한가요?</h1>
      <p className="body-s muted">우주의 색은 사람마다 다르게 느껴져요. 언제든 바꿀 수 있고, 기록은 그대로예요.</p>
      <Suspense fallback={<div className={styles.loading} aria-busy="true" />}><Sky /></Suspense>
    </div>
  );
}

async function Sky() {
  const me = await api<Me>("/v1/me");
  return <SkyCards sky={me.settings?.sky ?? "violet"} member={Boolean(me.membership?.active)} />;
}
