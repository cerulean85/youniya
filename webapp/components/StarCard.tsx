import { moodOf } from "@/lib/format";
import type { Analysis } from "@/lib/types";
import { StarFilled } from "./icons";
import styles from "./StarCard.module.css";

// Figma: Today Star Card. The three measures are 0–1 from the starlight prism.
export function StarCard({ analysis }: { analysis: Analysis }) {
  const meters = [
    { label: "별의 깊이", value: analysis.depth, color: "var(--primary)" },
    { label: "빛의 선명함", value: analysis.clarity, color: "var(--cyan)" },
    { label: "마음의 무게", value: analysis.weight, color: "var(--pink)" },
  ];
  return (
    <div className={styles.card}>
      <div className={styles.top}>
        <span className="caption muted">오늘의 별 카드</span>
        <span className={styles.badge}><StarFilled size={12} />{analysis.starlight} 별빛</span>
      </div>
      <div className={styles.num}><b>{analysis.starlight}</b><span>별빛</span></div>
      <p className={`observation ${styles.obs}`}>{analysis.observation}</p>
      {meters.map((m) => (
        <div key={m.label} className={styles.meter}>
          <span className="caption muted">{m.label}</span>
          <i style={{ ["--v" as string]: `${Math.round(m.value * 100)}%`, ["--c" as string]: m.color }} />
        </div>
      ))}
      <div className={styles.chips}>
        {analysis.moods.map((m) => {
          const mood = moodOf(m.mood);
          return <span key={m.mood} className={styles.chip} style={{ ["--c" as string]: mood.color }}>{mood.label}</span>;
        })}
      </div>
    </div>
  );
}
