"use client";

import { useState, useTransition } from "react";
import { NebulaFigure } from "@/components/NebulaFigure";
import { Check, Close } from "@/components/icons";
import { dateTime, moodOf } from "@/lib/format";
import { BASIC_SILHOUETTES, MAX_GUESTS, MAX_NAME, MIN_STARS, outlinePath, SILHOUETTES, type Dot } from "@/lib/nebula";
import type { StarSummary } from "@/lib/types";
import { createNebula, editNebula } from "../actions";
import styles from "./draw.module.css";

type Guest = { share_id: string; name: string; mood: StarSummary["mood"] };
type Step = "stars" | "shape" | "name";
const LABEL: Record<Step, string> = { stars: "별 고르기", shape: "모양 고르기", name: "이름 짓기" };

/** For W-43: the nebula being reshaped, opened with its current shape, stars and name. */
export type Editing = { id: string; name: string; silhouette: string | null; starIds: string[]; guestIds: string[]; shared: boolean };

// New (W-27 → 84 → 54): stars, shape, name. Reshape (W-43): shape, stars, name, saved with PATCH.
export function DrawNebula({ stars, guests, editing }: { stars: StarSummary[]; guests: Guest[]; editing?: Editing }) {
  const order: Step[] = editing ? ["shape", "stars", "name"] : ["stars", "shape", "name"];
  const [at, setAt] = useState(0);
  const step = order[at];
  const [picked, setPicked] = useState<string[]>(editing?.starIds ?? []);
  const [silhouette, setSilhouette] = useState<string | null>(editing ? editing.silhouette : "tree");
  const [guestIds, setGuestIds] = useState<string[]>(editing?.guestIds ?? []);
  const [name, setName] = useState(editing?.name ?? "");

  const [error, setError] = useState<string | null>(null);
  const [saving, start] = useTransition();

  const toggle = (id: string) => setPicked((p) => (p.includes(id) ? p.filter((x) => x !== id) : [...p, id]));
  const pickedStars = picked.map((id) => stars.find((s) => s.id === id)!).filter(Boolean);
  const figure = {
    silhouette,
    edges: silhouette ? [] : pickedStars.slice(1).map((_, i) => [i, i + 1]),
    dots: [...pickedStars.map((s): Dot => ({ mood: s.mood })), ...guestIds.map((): Dot => ({ guest: true }))],
  };
  const input = () => ({ name: name.trim(), silhouette, star_ids: picked, edges: figure.edges, guest_share_ids: guestIds });
  const save = () => start(async () => {
    const r = editing ? await editNebula(editing.id, input()) : await createNebula(input());
    if (r?.error) setError(r.error);
  });
  const next = () => setAt((a) => a + 1);
  const prev = () => setAt((a) => a - 1);

  return (
    <div className={styles.wrap}>
      <ol className={styles.steps} aria-label="단계">
        {order.map((s, i) => <li key={s} aria-current={i === at ? "step" : undefined} data-done={i < at}><span>{i + 1}</span>{LABEL[s]}</li>)}
      </ol>
      <div className={styles.body}>
        <section className={`card ${styles.stage}`} aria-label="미리 보기">
          <NebulaFigure width={560} height={480} figure={figure} label="그리는 중인 성운" />
        </section>
        <aside className={styles.side}>
          {step === "stars" && (
            <>
              <h1 className="h2">별을 골라 주세요</h1>
              <p className="body-m muted">{picked.length}개 골랐어요 · {MIN_STARS}개 이상이면 돼요</p>
              <div className={styles.list} role="group" aria-label="띄운 별">
                {stars.length === 0 && <p className="body-s faint">아직 띄운 별이 없어요.</p>}
                {stars.map((s) => {
                  const on = picked.includes(s.id);
                  return (
                    <button key={s.id} type="button" className={styles.pick} aria-pressed={on} onClick={() => toggle(s.id)}>
                      <span className={styles.dot} style={{ background: on ? "var(--gold)" : moodOf(s.mood).color }} />
                      <span className={styles.pickText}><span className="label-m">{s.title || "제목 없는 별"}</span><span className="caption faint">{dateTime(s.created_at)} · {s.starlight} 별빛</span></span>
                      {on ? <Close size={16} /> : null}
                    </button>
                  );
                })}
              </div>
              <p className="caption faint">간직한 별은 고를 수 없어요. 띄운 별만 성운이 될 수 있어요.</p>
              <div className={styles.nav}>
                {at > 0 ? <button type="button" className="btn btn-ghost" onClick={prev}>이전</button> : <span />}
                <button type="button" className="btn btn-primary" disabled={picked.length < MIN_STARS} onClick={next}>이어 보기</button>
              </div>
            </>
          )}
          {step === "shape" && (
            <>
              <h1 className="h2">{editing ? "모양을 바꿀까요?" : "어떤 모양으로 그릴까요?"}</h1>
              {editing && <p className="body-m muted">지금은 {editing.silhouette ? `${SILHOUETTES[editing.silhouette]?.name ?? editing.silhouette} 모양이에요` : "순서대로 이은 모양이에요"}. 다른 모양을 고르거나 그대로 두고 별을 다시 골라도 돼요.</p>}
              <div className={styles.shapes} role="radiogroup" aria-label="실루엣">
                {BASIC_SILHOUETTES.map((k) => (
                  <button key={k} type="button" role="radio" aria-checked={silhouette === k} className={styles.shape} onClick={() => setSilhouette(k)}>
                    <svg viewBox="0 0 56 56" width="56" height="56" aria-hidden="true"><path d={outlinePath(k, 56, 56)} fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" /></svg>
                    {SILHOUETTES[k].name}
                  </button>
                ))}
                <button type="button" role="radio" aria-checked={silhouette === null} className={styles.shape} onClick={() => setSilhouette(null)}>
                  <svg viewBox="0 0 56 56" width="56" height="56" aria-hidden="true"><path d="M10 40 L22 18 L34 30 L46 12" fill="none" stroke="currentColor" strokeWidth="1.5" /></svg>
                  순서대로 잇기
                </button>
              </div>
              {guests.length > 0 && (
                <div className={styles.guests}>
                  <span className="label-m">손님별 들이기</span>
                  <span className="caption faint">공명을 남긴 광장의 별을 {MAX_GUESTS}개까지 함께 둘 수 있어요. 색만 함께 와요.</span>
                  {guests.map((g) => {
                    const on = guestIds.includes(g.share_id);
                    return (
                      <label key={g.share_id} className={styles.guest}>
                        <input type="checkbox" checked={on} disabled={!on && guestIds.length >= MAX_GUESTS}
                          onChange={() => setGuestIds((x) => (on ? x.filter((y) => y !== g.share_id) : [...x, g.share_id]))} />
                        <span className={styles.dot} style={{ background: moodOf(g.mood).color }} />{g.name}
                      </label>
                    );
                  })}
                </div>
              )}
              {editing && (
                <ul className={styles.notes}>
                  <li>띄운 별을 {MIN_STARS}개 이상 골라야 해요. 이름은 {MAX_NAME}자까지예요.</li>
                  {editing.shared && <li>우주 광장에 띄운 성운이라, 광장에서도 새 모양으로 바뀌어요.</li>}
                </ul>
              )}
              <div className={styles.nav}>
                {at > 0 ? <button type="button" className="btn btn-ghost" onClick={prev}>이전</button> : <span />}
                <button type="button" className="btn btn-primary" onClick={next}>{editing ? "다음 · 별 다시 고르기" : "이어 보기"}</button>
              </div>
            </>
          )}
          {step === "name" && (
            <>
              <h1 className="h2">이 성운의 이름은요?</h1>
              <input className={styles.name} value={name} maxLength={MAX_NAME} onChange={(e) => setName(e.target.value)} placeholder="느린 저녁의 성운" aria-label="성운 이름" autoFocus />
              <p className="caption faint">{name.length} / {MAX_NAME}자</p>
              {error && <p className="body-s" role="alert" style={{ color: "var(--anger)" }}>{error}</p>}
              <div className={styles.nav}>
                <button type="button" className="btn btn-ghost" onClick={prev}>이전</button>
                <button type="button" className="btn btn-primary" disabled={!name.trim() || picked.length < MIN_STARS || saving} onClick={save}>
                  {saving ? "저장하는 중…" : <><Check size={16} />{editing ? "바꾼 모양 저장하기" : "성운 완성하기"}</>}
                </button>
              </div>
            </>
          )}
        </aside>
      </div>
    </div>
  );
}
