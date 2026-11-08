import Link from "next/link";
import { dateTime } from "@/lib/format";
import type { StarSummary } from "@/lib/types";
import { Star, StarFilled } from "./icons";
import styles from "./StarRow.module.css";

// Figma: Star Row (State=Floated / Kept).
export function StarRow({ star }: { star: StarSummary }) {
  const floated = star.state === "floated";
  return (
    <Link href={`/stars/${star.id}`} className={`card ${styles.row}`} prefetch={false}>
      <span className={styles.glyph} data-floated={floated}>{floated ? <StarFilled size={18} /> : <Star size={18} />}</span>
      <span className={styles.text}>
        <span className="label-m">{star.title || "제목 없는 별"}</span>
        <span className="caption faint">{dateTime(star.created_at)}</span>
      </span>
      {floated && star.starlight != null ? (
        <span className={styles.badge}><StarFilled size={12} />{star.starlight}<small>별빛</small></span>
      ) : (
        <span className="label-s muted">{star.analysis_failed ? "다시 띄워 주세요" : "간직한 별"}</span>
      )}
    </Link>
  );
}
