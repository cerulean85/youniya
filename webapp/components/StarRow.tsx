import Link from "next/link";
import { longDate, dateTime, moodOf } from "@/lib/format";
import type { StarSummary } from "@/lib/types";
import { StarGlyph } from "./StarGlyph";
import styles from "./StarRow.module.css";

// Figma Web 시안 v2 · 기록 (595:28950): no box; the star's own shape in its mood's light, the title in serif,
// and the starlight on the right.
export function StarRow({ star }: { star: StarSummary }) {
  const lit = (star.has_starlight ?? star.state === "floated") && star.starlight != null;
  const m = moodOf(star.mood);
  return (
    <Link href={`/stars/${star.id}`} className={`v2-hover ${styles.row}`} prefetch={false}>
      <span className={`v2-glow ${styles.glow}`} style={{ ["--c" as string]: m.color, opacity: lit ? undefined : 0.35 }} />
      <span className={styles.glyph} data-lit={lit}>
        {lit ? <StarGlyph points={star.shape?.points} sharpness={star.shape?.sharpness} mood={star.mood} size={40} twinkle />
          : <StarGlyph points={4} mood={star.mood} size={20} />}
      </span>
      <span className={styles.text}>
        <span className={styles.title}>{star.title || "제목 없는 별"}</span>
        <span className={styles.when}>{longDate(star.created_at)} · {dateTime(star.created_at).split(" · ")[1]}</span>
      </span>
      {lit ? (
        <span className={styles.light}><b>{star.starlight}</b><small>별빛</small></span>
      ) : (
        <span className={styles.none}>{star.analysis_failed ? "다시 띄워 주세요" : "별빛 없는 별"}</span>
      )}
    </Link>
  );
}
