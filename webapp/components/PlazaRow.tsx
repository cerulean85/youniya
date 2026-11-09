import Link from "next/link";
import type { PlazaStar } from "@/lib/types";
import { StarGlyph } from "./StarGlyph";
import styles from "./PlazaRow.module.css";

// One shared star (W-44, W-50): 대표 문장, then 별지기 이름 · 「the writer's title」 · when. No counts.
export function PlazaRow({ star: s, ago, nickname = true }: { star: PlazaStar; ago: string; nickname?: boolean }) {
  return (
    <Link href={`/plaza/stars/${s.id}`} className={styles.row} data-unlit={!s.has_starlight || undefined} prefetch={false}>
      <span className={styles.thumb}>
        <StarGlyph points={s.has_starlight ? s.shape?.points : 4} sharpness={s.shape?.sharpness} mood={s.mood} size={s.has_starlight ? 24 : 16} />
      </span>
      <span className={styles.text}>
        <span className="observation">“{s.quote}”</span>
        <span className={styles.meta}>
          {nickname && s.nickname && <span className={styles.nick}>{s.nickname}</span>}
          <span>「{s.name}」</span>
          <span>· {s.has_starlight ? ago : "별빛 없음"}</span>
        </span>
      </span>
      <span className={styles.res} data-on={s.resonated} aria-label={s.resonated ? "공명했어요" : "공명 전"}>✦</span>
    </Link>
  );
}
