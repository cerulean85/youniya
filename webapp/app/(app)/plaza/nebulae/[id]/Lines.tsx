"use client";

import { useActionState, useRef, useState } from "react";
import { useFormStatus } from "react-dom";
import { leaveLine, reportLine } from "../../stars/[id]/actions";
import { REASONS } from "../../stars/[id]/PlazaActions";
import styles from "./lines.module.css";

type Line = { id: string; text: string; created_at: string; mine: boolean };

// 74 별빛 한 줄: lines from the last day; one per person, up to 60 characters, checked before posting.
export function Lines({ shareId, open, items, can_leave, max_length }: { shareId: string; open: boolean; items: Line[]; can_leave: boolean; max_length: number }) {
  const [state, action] = useActionState(leaveLine.bind(null, shareId), null);
  const [text, setText] = useState("");
  const [reporting, setReporting] = useState<string | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <section className={styles.lines} aria-labelledby="lines-title">
      <h2 id="lines-title" className="label-m">별빛 한 줄</h2>
      {!open ? <p className="body-s faint">이 성운은 별빛 한 줄을 받지 않아요.</p> : (
        <>
          {items.length === 0 && <p className="body-s faint">하루 동안 남긴 한 줄이 이곳에 보여요.</p>}
          <ul>
            {items.map((l) => (
              <li key={l.id}>
                <p className="body-m">{l.text}</p>
                {l.mine ? <span className="caption faint">내가 남긴 한 줄</span>
                  : <button type="button" onClick={() => { setReporting(l.id); dialog.current?.showModal(); }}>신고</button>}
              </li>
            ))}
          </ul>
          {can_leave && !state?.ok ? (
            <form action={action} className={styles.form}>
              <input name="text" value={text} onChange={(e) => setText(e.target.value)} maxLength={max_length} placeholder="마음이 닿았다면 한 줄을 남겨 보세요" aria-label="별빛 한 줄" />
              <span className="caption faint">{text.length}/{max_length}</span>
              <Send disabled={!text.trim()} />
            </form>
          ) : (
            <p className="caption faint">{state?.ok ? "한 줄을 남겼어요. 하루가 지나면 사라져요." : "이 성운에는 이미 한 줄을 남겼어요."}</p>
          )}
          {state?.error && <p className="body-s" role="alert" style={{ color: "var(--anger)" }}>{state.error}</p>}
        </>
      )}
      <dialog ref={dialog} className={`card ${styles.dialog}`} aria-labelledby="line-report">
        {reporting && (
          <form action={async (f) => { await reportLine(reporting, f); dialog.current?.close(); }}>
            <h2 id="line-report" className="h2">이 별빛을 신고할까요?</h2>
            <p className="body-s muted">신고한 별빛은 바로 가려지고 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요.</p>
            <fieldset>
              {REASONS.map(([k, l], i) => <label key={k}><input type="radio" name="reason" value={k} defaultChecked={i === 0} />{l}</label>)}
            </fieldset>
            <label><input type="checkbox" name="block" />이 별지기도 차단하기</label>
            <div className={styles.actions}>
              <button type="button" className="btn btn-ghost" onClick={() => dialog.current?.close()}>취소</button>
              <button className="btn btn-primary">신고하기</button>
            </div>
          </form>
        )}
      </dialog>
    </section>
  );
}

function Send({ disabled }: { disabled: boolean }) {
  const { pending } = useFormStatus();
  return <button className="btn btn-secondary" disabled={disabled || pending}>{pending ? "남기는 중…" : "남기기"}</button>;
}
