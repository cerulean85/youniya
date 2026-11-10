import type { Metadata } from "next";
import { Suspense } from "react";
import { Star } from "@/components/icons";
import { api } from "@/lib/api";
import { longDate } from "@/lib/format";
import { Back } from "../Back";
import { UnblockButton } from "../SettingsControls";
import styles from "../settings.module.css";

export const metadata: Metadata = { title: "차단한 별지기" };

type Block = { id: string; created_at: string; source: "star" | "line" | "star_line" | "nebula" | string };
const WHERE: Record<string, string> = { star: "광장의 별", line: "별빛 한 줄", star_line: "별빛 한 줄", nebula: "성운" };

// Figma W-82: the API keeps who it was to itself (설정 › 차단한 별지기: when and where, never who).
export default function BlocksPage() {
  return (
    <div className={styles.page}>
      <Back />
      <Suspense fallback={<div className={styles.loading} aria-busy="true" />}><Blocks /></Suspense>
    </div>
  );
}

async function Blocks() {
  const { items } = await api<{ items: Block[] }>("/v1/blocks");
  if (items.length === 0) return (
    <div className={styles.empty}>
      <Star size={28} />
      <h1 className="h3">차단한 별지기가 없어요</h1>
      <p className="body-s muted">광장에서 불편한 별지기를 차단하면 여기에 모여요.</p>
    </div>
  );
  return (
    <>
      <p className="body-s muted">차단한 별지기 {items.length}명이에요. 이 사람들의 별과 별빛 한 줄은 내 화면에 보이지 않아요. 풀면 다시 보여요.</p>
      <ul className={styles.items}>
        {items.map((b) => (
          <li key={b.id}>
            <div className={styles.item}>
              <Star size={16} />
              <span className={styles.itemText}><span className="label-m">{WHERE[b.source] ?? "광장"}에서 차단한 별지기</span><span className="caption faint">{longDate(b.created_at)} 차단</span></span>
            </div>
            <UnblockButton id={b.id} />
          </li>
        ))}
      </ul>
    </>
  );
}
