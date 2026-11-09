"use client";

import { useActionState, useRef, useState } from "react";
import { useFormStatus } from "react-dom";

export type ExtraField = { name: string; label: string; type?: "text" | "number" | "date" | "textarea" | "select"; options?: [string, string][]; required?: boolean; defaultValue?: string };
export type ReasonButton = { key: string; label: string; danger?: boolean; primary?: boolean; disabled?: boolean; field?: "amount" | "days"; fields?: ExtraField[]; confirm?: string };
export type ReasonState = { error?: string; ok?: string } | null;

// A button per action; each opens a box that needs a reason (18.1) before anything happens.
export function ReasonActions({ buttons, action }: { buttons: ReasonButton[]; action: (prev: ReasonState, form: FormData) => Promise<ReasonState> }) {
  const [state, run] = useActionState(action, null);
  const [picked, setPicked] = useState<ReasonButton | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <div className="reason">
      <div className="actions">
        {buttons.map((b) => (
          <button key={b.key} type="button" className={`btn ${b.danger ? "btn-danger" : b.primary ? "btn-primary" : ""}`} disabled={b.disabled} onClick={() => { setPicked(b); dialog.current?.showModal(); }}>{b.label}</button>
        ))}
      </div>
      {state?.ok && <p className="faint" role="status">{state.ok}</p>}
      {state?.error && <p className="error" role="alert">{state.error}</p>}
      <dialog ref={dialog} className="card" aria-labelledby="reason-title">
        <form key={picked?.key} action={async (f) => { await run(f); dialog.current?.close(); }}>
          <h2 id="reason-title">{picked?.label}</h2>
          {picked?.confirm && <p className="notice">{picked.confirm}</p>}
          <input type="hidden" name="action" value={picked?.key ?? ""} />
          {picked?.field === "amount" && <label className="field"><span>지급할 코인 (1~10,000)</span><input name="amount" type="number" min={1} max={10000} required /></label>}
          {picked?.field === "days" && (
            <label className="field"><span>늘릴 기간</span>
              <select name="days" defaultValue="7"><option value="7">7일</option><option value="30">30일</option></select>
            </label>
          )}
          {picked?.fields?.map((f) => (
            <label key={`${picked.key}-${f.name}`} className="field"><span>{f.label}</span>
              {f.type === "textarea" ? <textarea name={f.name} rows={3} required={f.required} defaultValue={f.defaultValue} />
                : f.type === "select" ? <select name={f.name} defaultValue={f.defaultValue}>{f.options?.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select>
                : <input name={f.name} type={f.type ?? "text"} required={f.required} defaultValue={f.defaultValue} />}
            </label>
          ))}
          <label className="field"><span>사유 (필수 · 운영 기록에 남아요)</span><textarea name="reason" rows={3} required /></label>
          {state?.error && <p className="error" role="alert">{state.error}</p>}
          <div className="dialog-actions">
            <button type="button" className="btn" onClick={() => dialog.current?.close()}>취소</button>
            <Submit danger={Boolean(picked?.danger)} />
          </div>
        </form>
      </dialog>
    </div>
  );
}

function Submit({ danger }: { danger: boolean }) {
  const { pending } = useFormStatus();
  return <button className={`btn ${danger ? "btn-danger" : "btn-primary"}`} disabled={pending}>{pending ? "처리하는 중…" : "조치하기"}</button>;
}
