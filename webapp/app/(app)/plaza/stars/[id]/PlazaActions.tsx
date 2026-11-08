"use client";

import { useOptimistic, useRef, useTransition } from "react";
import { useFormStatus } from "react-dom";
import { Heart } from "@/components/icons";
import { blockOwner, reportShare, toggleBeside, toggleResonance, type Kind } from "./actions";
import styles from "./plaza-star.module.css";

export const REASONS = [
  ["hurtful", "상처를 주는 말이에요"],
  ["personal_info", "개인정보가 드러나 있어요"],
  ["spam", "광고나 스팸이에요"],
  ["other", "그 밖의 이유가 있어요"],
] as const;

type Marks = { resonated: boolean; beside: boolean };

export function PlazaActions({ id, resonated, beside, kind = "star" }: { id: string; kind?: Kind } & Marks) {
  const what = kind === "star" ? "별" : "성운";
  const [state, setOptimistic] = useOptimistic<Marks, Partial<Marks>>({ resonated, beside }, (s, patch) => ({ ...s, ...patch }));
  const [, start] = useTransition();
  const report = useRef<HTMLDialogElement>(null);
  const block = useRef<HTMLDialogElement>(null);

  return (
    <>
      <div className={styles.actions}>
        <button type="button" className={`btn ${state.resonated ? styles.on : "btn-secondary"}`} aria-pressed={state.resonated}
          onClick={() => start(async () => { setOptimistic({ resonated: !state.resonated }); await toggleResonance(kind, id, !state.resonated); })}>
          <Heart size={16} />{state.resonated ? "공명했어요" : "공명 남기기"}
        </button>
        <button type="button" className="btn btn-primary" aria-pressed={state.beside}
          onClick={() => start(async () => { setOptimistic({ beside: !state.beside }); await toggleBeside(kind, id, !state.beside); })}>
          {state.beside ? `곁에 둔 ${what}이에요` : "곁에 두기"}
        </button>
      </div>
      <div className={styles.more}>
        <button type="button" onClick={() => report.current?.showModal()}>신고하기</button>
        <button type="button" onClick={() => block.current?.showModal()}>이 별지기 차단</button>
      </div>

      <dialog ref={report} className={`card ${styles.dialog}`} aria-labelledby="report-title">
        <form action={reportShare.bind(null, kind, id)}>
          <h2 id="report-title" className="h2">이 {what}을 신고할까요?</h2>
          <p className="body-s muted">신고한 {what}은 바로 가려지고 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요.</p>
          <fieldset className={styles.reasons}>
            <legend className="label-s faint">이유</legend>
            {REASONS.map(([key, label], i) => (
              <label key={key}><input type="radio" name="reason" value={key} defaultChecked={i === 0} />{label}</label>
            ))}
          </fieldset>
          <label className={styles.check}><input type="checkbox" name="block" />이 별지기도 차단하기</label>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => report.current?.close()}>취소</button>
            <Submit label="신고하기" busy="보내는 중…" />
          </div>
        </form>
      </dialog>

      <dialog ref={block} className={`card ${styles.dialog}`} aria-labelledby="block-title">
        <form action={blockOwner.bind(null, kind, id)}>
          <h2 id="block-title" className="h2">이 별지기를 차단할까요?</h2>
          <p className="body-s muted">서로의 별과 성운, 별빛 한 줄이 어디에서도 보이지 않아요. 상대에게는 알리지 않고, 설정 › 차단한 별지기에서 풀 수 있어요.</p>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => block.current?.close()}>취소</button>
            <Submit label="차단하기" busy="차단하는 중…" />
          </div>
        </form>
      </dialog>
    </>
  );
}

function Submit({ label, busy }: { label: string; busy: string }) {
  const { pending } = useFormStatus();
  return <button className={`btn ${styles.danger}`} disabled={pending}>{pending ? busy : label}</button>;
}
