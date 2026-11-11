import Link from "next/link";
import type { PlazaStar } from "@/lib/types";
import { moodOf } from "@/lib/format";
import { StarGlyph } from "./StarGlyph";
import styles from "./PlazaRow.module.css";

// One shared star (W-44, W-50; Web 시안 v2 593:28550): 대표 문장, then 별지기 이름 · 「the writer's title」 · when. No counts.
export function PlazaRow({ star: s, ago, nickname = true }: { star: PlazaStar; ago: string; nickname?: boolean }) {
  return (
    <Link href={`/plaza/stars/${s.id}`} className={`v2-hover ${styles.row}`} data-unlit={!s.has_starlight || undefined} prefetch={false}>
      <span className={`v2-glow ${styles.glow}`} style={{ ["--c" as string]: moodOf(s.mood).color, opacity: s.has_starlight ? undefined : 0.4 }} />
      <span className={styles.thumb}>
        <StarGlyph points={s.has_starlight ? s.shape?.points : 4} sharpness={s.shape?.sharpness} mood={s.mood} size={s.has_starlight ? 40 : 22} twinkle={s.has_starlight} />
      </span>
      <span className={styles.text}>
        <span className={styles.quote}>“{s.quote}”</span>
        <span className={styles.meta}>
          {nickname && <span className={styles.nick}>{s.nickname ?? "익명의 별지기"}</span>}
          <span>「{s.name}」</span>
          <span>· {s.has_starlight ? ago : "별빛 없음"}</span>
        </span>
      </span>
      <span className={styles.res} data-on={s.resonated} aria-label={s.resonated ? "공명했어요" : "공명 전"}>✦</span>
    </Link>
  );
}
