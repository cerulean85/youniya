import Link from "next/link";
import type { PlazaStar } from "@/lib/types";
import { moodOf } from "@/lib/format";
import { StarGlyph } from "./StarGlyph";
import styles from "./PlazaRow.module.css";

// One shared star (Figma 웹 v1.1 · 우주 광장 639:31296): the writer's title, the 대표 문장 under it, then
// 별지기 이름 · when · depth. No counts for anyone else's star.
export function PlazaRow({ star: s, ago, nickname = true }: { star: PlazaStar; ago: string; nickname?: boolean }) {
  return (
    <Link href={`/plaza/stars/${s.id}`} className={styles.row} data-unlit={!s.has_starlight || undefined} prefetch={false}>
      <span className={styles.thumb}>
        <span className="v2-glow" style={{ ["--c" as string]: moodOf(s.mood).color, inset: -18, opacity: s.has_starlight ? 0.8 : 0.3 }} />
        <StarGlyph points={s.has_starlight ? s.shape?.points : 4} sharpness={s.shape?.sharpness} mood={s.mood} size={s.has_starlight ? 36 : 20} />
      </span>
      <span className={styles.text}>
        <span className={styles.title}>{s.name || "제목 없는 별"}</span>
        <span className={styles.quote}>“{s.quote}”</span>
        <span className="caption faint">
          {[nickname && (s.nickname ?? "익명의 별지기"), ago, s.has_starlight ? `깊이 ${s.depth_level}단계` : "별빛 없는 별"].filter(Boolean).join(" · ")}
        </span>
      </span>
      {s.resonated && <span className={styles.res} aria-label="공명했어요">✦</span>}
    </Link>
  );
}
