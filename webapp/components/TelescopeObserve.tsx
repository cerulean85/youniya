"use client";

import { useEffect, useState } from "react";
import { useFormStatus } from "react-dom";
import styles from "./TelescopeObserve.module.css";

const LENSES = ["별의 깊이", "빛의 선명함", "마음의 무게"];
const PASS = 2.4; // seconds per lens
const FEELING = ["마음", "기다", "느림", "쉬고", "싶", "슬", "외로", "화", "불안", "괜찮", "몰라", "좋", "힘들", "무서", "걱정", "아프", "눈물", "미안", "고마"];

function sentencesOf(body: string) {
  return body.split(/(?<=[.!?。…])\s+|\n+/).map((s) => s.trim()).filter((s) => s.length >= 2).slice(0, 7);
}

/** Up to three sentences with a feeling word light up (the same guess as iOS 88; the report has the real ones). */
function litOf(sentences: string[]) {
  const out = sentences.map((s, i) => (i > 0 && FEELING.some((w) => s.includes(w)) ? i : -1)).filter((i) => i >= 0);
  if (!out.length && sentences.length > 1) out.push(sentences.length - 1);
  return out.slice(0, 3);
}

// Figma W-74 (iOS 25 / 88): while the telescope reads the star, a beam passes over its sentences and lights
// the ones where a feeling stays. Sits inside the telescope form; 백그라운드로 두기 closes the dialog and the
// request carries on; the result lands on the star page.
export function TelescopeObserve({ body, onAway }: { body: string; onAway: () => void }) {
  const { pending } = useFormStatus();
  return pending ? <Scene body={body} onAway={onAway} /> : null;
}

// Mounted only while the telescope works, so its clock starts at zero each time.
function Scene({ body, onAway }: { body: string; onAway: () => void }) {
  const [t, setT] = useState(0);
  useEffect(() => {
    const start = performance.now();
    let raf = 0;
    const tick = () => { setT((performance.now() - start) / 1000); raf = requestAnimationFrame(tick); };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, []);

  const sentences = sentencesOf(body);
  const lit = litOf(sentences);
  const lens = Math.min(2, Math.floor(t / PASS));
  const progress = (t % PASS) / PASS;
  const shown = t >= PASS ? lit : lit.filter((i) => (i + 1) / Math.max(1, sentences.length) <= progress);
  return (
    <div className={styles.overlay} role="status" aria-live="polite">
      <div className={styles.column}>
        <h2 className="h2">문장 사이를 비추는 중</h2>
        <p className="body-m muted">망원경 빛이 글을 천천히 지나가며, 감정의 신호가 머문 문장에 불을 켜요.</p>
        <div className={styles.tags}>
          <span className={styles.found}><i />{shown.length ? `감정 신호 ${shown.length}개를 찾았어요` : "감정 신호를 찾는 중"}</span>
          <span className={styles.tag}>렌즈 {lens + 1} / 3</span>
        </div>
        <div className={styles.scan} aria-hidden="true">
          {sentences.map((s, i) => <p key={i} data-lit={shown.includes(i) || undefined}>{s}</p>)}
          <span className={styles.beam} style={{ top: `${progress * 100}%` }} />
        </div>
        <div className={styles.tags}>
          {LENSES.map((l, i) => <span key={l} className={styles.lens} data-state={i < lens ? "done" : i === lens ? "now" : undefined}>{l}{i < lens ? " ✓" : ""}</span>)}
        </div>
        <p className="caption faint">불이 켜진 문장은 별 상세의 망원경 결과에 근거 문장으로 함께 보여 드려요.</p>
        <button type="button" className={`btn btn-ghost ${styles.leave}`} onClick={onAway}>백그라운드로 두기</button>
      </div>
    </div>
  );
}
