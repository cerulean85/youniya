import { Telescope as TelescopeIcon } from "@/components/icons";
import { api } from "@/lib/api";
import { moodOf } from "@/lib/format";
import type { Analysis, TelescopeOffer, TelescopeReport } from "@/lib/types";
import { OpenTelescope } from "./StarActions";
import styles from "./telescope.module.css";

/** This star's own report: the newest one-star report that names it. */
async function findReport(id: string): Promise<TelescopeReport | null> {
  const { items } = await api<{ items: { id: string; star_count: number }[] }>("/v1/telescope/reports");
  const single = items.filter((r) => r.star_count === 1).slice(0, 30);
  const reports = await Promise.all(single.map((r) => api<TelescopeReport>(`/v1/telescope/reports/${r.id}`)));
  return reports.find((r) => r.star_ids[0] === id) ?? null;
}

// Figma W-54: the mind telescope inside star detail, folded with 접기. The name ending in 별 shows only here.
export async function Telescope({ id, analysis }: { id: string; analysis: Analysis }) {
  const report = await findReport(id);
  if (!report) {
    const offer = await api<TelescopeOffer>("/v1/telescope/offer");
    return (
      <div id="telescope" className={`card ${styles.offer}`}>
        <span className={styles.head}><TelescopeIcon size={16} />마음 망원경</span>
        <p className="body-s">{analysis.telescope_teaser ?? "별빛 풀이보다 한 걸음 더, 글 속에 숨은 마음의 결을 들여다봐요."}</p>
        <OpenTelescope id={id} label={offer.free ? `마음 망원경 켜기 · 무료 ${offer.free_left}번 남음` : `마음 망원경 켜기 · ${offer.cost}코인`} />
      </div>
    );
  }
  const r = report.report;
  return (
    <details id="telescope" className={styles.telescope} open>
      <summary>
        <span className="label-l">마음 망원경 · {r.star_name}</span>
        <span className={styles.toggle} aria-hidden="true" />
      </summary>
      {r.fog ? (
        <section className={`card ${styles.card}`}>
          <h3 className="label-m">{r.fog.title}</h3>
          <p className="caption muted">{r.fog.note}</p>
          {r.fog.items.map((it) => (
            <div key={it.label} className={styles.item}>
              <span className={styles.itemLabel}>{it.label}</span>
              <blockquote className={styles.quote}>“{it.quote}”</blockquote>
              <p className="caption muted">{it.note}</p>
            </div>
          ))}
        </section>
      ) : r.signals.length > 0 && (
        <section className={`card ${styles.card}`}>
          <h3 className="label-m">마음이 머문 문장</h3>
          {r.signals.map((s) => <blockquote key={s.sentence} className={styles.quote}>“{s.sentence}”</blockquote>)}
        </section>
      )}
      {r.emotions.length > 0 && (
        <section className={`card ${styles.card}`}>
          <h3 className="label-m">감정의 결과 흐름</h3>
          <div className={styles.bar} aria-hidden="true">
            {r.emotions.map((e) => <span key={e.mood} style={{ flexGrow: e.percent, background: moodOf(e.mood).color }} />)}
          </div>
          <p className={styles.legend}>
            {r.emotions.map((e) => <span key={e.mood} style={{ ["--c" as string]: moodOf(e.mood).color }}>{e.label} {e.percent}%</span>)}
          </p>
          {r.flow?.map((f) => (
            <div key={f.part} className={styles.flow}>
              <span className="caption faint">{f.part}</span>
              <span><span className={styles.flowMoods}>{f.moods}</span><span className="caption muted">{f.note}</span></span>
            </div>
          ))}
          {r.evidence && <p className="body-s muted">{r.evidence}</p>}
        </section>
      )}
      {r.question && (
        <section className={`card ${styles.question}`}>
          <span className={styles.head}>스스로 물어볼 질문</span>
          <p className="observation">{r.question}</p>
        </section>
      )}
    </details>
  );
}
