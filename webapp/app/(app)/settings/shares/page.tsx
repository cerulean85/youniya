import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Star } from "@/components/icons";
import { api } from "@/lib/api";
import { dateTime } from "@/lib/format";
import type { MyShare } from "@/lib/types";
import { Back } from "../Back";
import { UnshareButton } from "../SettingsControls";
import styles from "../settings.module.css";

export const metadata: Metadata = { title: "나눈 별" };

// Figma W-77 (iOS SharedStarsView) and W-78 (비어 있음).
export default function SharesPage() {
  return (
    <div className={styles.page}>
      <Back />
      <Suspense fallback={<div className={styles.loading} aria-busy="true" />}><Shares /></Suspense>
    </div>
  );
}

async function Shares() {
  const { stars } = await api<{ stars: MyShare[] }>("/v1/me/shares");
  if (stars.length === 0) return (
    <div className={styles.empty}>
      <Star size={28} />
      <h1 className="h3">아직 나눈 별이 없어요</h1>
      <p className="body-s muted">띄운 별을 열어 &lsquo;우주 광장에 나누기&rsquo;를 누르면<br />여기에 모여요.</p>
      <Link href="/plaza" className="btn btn-secondary">우주 광장 둘러보기</Link>
    </div>
  );
  return (
    <>
      <p className="body-s muted">우주 광장에 나눈 별 {stars.length}개예요. 거두면 광장에서 바로 사라지고, 받은 공명과 별빛 한 줄은 그대로 간직돼요.</p>
      <ul className={styles.items}>
        {stars.map((s) => (
          <li key={s.id}>
            <Link href={`/stars/${s.star_id}`} className={styles.item}>
              <Star size={16} />
              <span className={styles.itemText}><span className="label-m">{s.title || s.name || "제목 없는 별"}</span><span className="caption faint">{dateTime(s.created_at)}</span></span>
              {s.starlight != null ? <span className={styles.badge}>✦ {s.starlight} 별빛</span> : <span className={`${styles.badge} ${styles.badgeDim}`}>별빛 없는 별</span>}
            </Link>
            <UnshareButton starId={s.star_id} />
          </li>
        ))}
      </ul>
    </>
  );
}
