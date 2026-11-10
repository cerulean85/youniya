import { Telescope as TelescopeIcon } from "@/components/icons";
import { api } from "@/lib/api";
import { moodOf } from "@/lib/format";
import type { Analysis, Star, TelescopeOffer } from "@/lib/types";
import { OpenTelescope } from "./StarActions";
import styles from "./telescope.module.css";

const PARTS = [["start", "글의 시작"], ["middle", "글의 중간"], ["end", "글의 끝"]] as const;

// Figma W-54: the mind telescope inside star detail, folded with 접기. The name ending in 별 shows only here.
export async function Telescope({ id, analysis, telescope }: { id: string; analysis: Analysis; telescope: Star["telescope"] }) {
  if (!telescope) {
    const offer = await api<TelescopeOffer>("/v1/telescope/offer");
    return (
      <div id="telescope" className={`card ${styles.offer}`}>
        <span className={styles.head}><TelescopeIcon size={16} />마음 망원경</span>
        <p className="body-s">{analysis.telescope_teaser ?? "별빛 풀이보다 한 걸음 더, 글 속에 숨은 마음의 결을 들여다봐요."}</p>
        <OpenTelescope id={id} label={offer.free ? `마음 망원경 켜기 · 무료 ${offer.free_left}번 남음` : `마음 망원경 켜기 · ${offer.cost}코인`}
          cost={offer.free ? `무료 몫을 1번 써요(${offer.free_left}번 남음).` : `${offer.cost}코인이 들어요(보유 ${offer.coins}).`} />
      </div>
    );
  }
  const r = telescope.report;
  const fog = r.fog_items ?? [];
  return (
    <details id="telescope" className={styles.telescope} open>
      <summary>
        <span className="label-l">마음 망원경 · {r.star_name}</span>
        <span className={styles.toggle} aria-hidden="true" />
      </summary>
      {fog.length > 0 ? (
        <section className={`card ${styles.card}`}>
          <h3 className="label-m">마음을 가린 안개</h3>
          <p className="caption muted">글 속에서 마음을 조금 흐리게 만든 말버릇이에요. 고칠 점이 아니라, 알아차릴 자리예요.</p>
          {fog.map((f) => (
            <div key={`${f.kind}-${f.sentence}`} className={styles.item}>
              <span className={styles.itemLabel}>{f.label}</span>
              <blockquote className={styles.quote}>“{f.sentence}”</blockquote>
              {f.note && <p className="caption muted">{f.note}</p>}
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
          {r.mood_flow && PARTS.map(([k, label]) => (
            <div key={k} className={styles.flow}>
              <span className="caption faint">{label}</span>
              <span className={styles.flowMoods} style={{ color: moodOf(r.mood_flow![k]).color }}>{moodOf(r.mood_flow![k]).label}</span>
            </div>
          ))}
          {(r.mood_interpretation || r.evidence) && <p className="body-s muted">{r.mood_interpretation || r.evidence}</p>}
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
