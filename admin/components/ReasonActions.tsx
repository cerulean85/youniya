"use client";

import { useActionState, useEffect, useRef, useState, startTransition } from "react";

export type ExtraField = { name: string; label: string; type?: "text" | "number" | "date" | "datetime-local" | "textarea" | "select"; options?: [string, string][]; required?: boolean; defaultValue?: string };
export type ReasonButton = {
  key: string; label: string; danger?: boolean; primary?: boolean; disabled?: boolean; field?: "amount" | "days"; fields?: ExtraField[]; confirm?: string;
  /** Panel rows: the heading this action sits under (광장 이용, 이름, 코인 · owner …). */
  group?: string;
  /** Dialog title, facts shown before the reason (별지기, 결제, 남은 코인), and the execute button's label. */
  title?: string; details?: [string, string][]; submit?: string;
  /** A one-time value (setup link, password) comes back in its own dialog. */
  result?: { title: string; note?: string; copy: string };
  /** In a table, a rule-breaking exception (예외 환불) reads plain rather than red; its dialog still warns. */
  quiet?: boolean;
};
export type ReasonState = { error?: string; ok?: string; secret?: string } | null;

/**
 * Each action opens a box that needs a reason (18.1) before anything happens.
 * `look`: "buttons" (header, outlined for primary), "text" (inside rows and tables), "rows" (grouped rows in an action panel).
 */
export function ReasonActions({ buttons, action, look = "buttons" }: { buttons: ReasonButton[]; action: (prev: ReasonState, form: FormData) => Promise<ReasonState>; look?: "buttons" | "text" | "rows" }) {
  const [state, run, pending] = useActionState(action, null);
  const [picked, setPicked] = useState<ReasonButton | null>(null);
  const [amount, setAmount] = useState("");
  const dialog = useRef<HTMLDialogElement>(null);
  const result = useRef<HTMLDialogElement>(null);
  const form = useRef<HTMLFormElement>(null);
  const handled = useRef<ReasonState>(null);

  // Close and clear only after it worked; on an error the box stays open with what was typed.
  useEffect(() => {
    if (!state || state === handled.current) return;
    handled.current = state;
    if (state.error) return;
    form.current?.reset();
    dialog.current?.close();
    if (state.secret && picked?.result) result.current?.showModal();
  }, [state, picked]);

  const open = (b: ReasonButton) => { setPicked(b); setAmount(""); dialog.current?.showModal(); };
  const trigger = (b: ReasonButton) => {
    if (look === "rows") return <button key={b.key} type="button" className={`act-row${b.danger ? " danger" : ""}`} disabled={b.disabled} onClick={() => open(b)}>{b.label}</button>;
    if (look === "text") return <button key={b.key} type="button" className={`btn-text${b.danger && !b.quiet ? " danger" : ""}`} disabled={b.disabled} onClick={() => open(b)}>{b.label}</button>;
    return <button key={b.key} type="button" className={`btn ${b.primary ? "btn-outline" : ""}`} disabled={b.disabled} onClick={() => open(b)}>{b.label}</button>;
  };
  const groups = [...new Set(buttons.map((b) => b.group ?? ""))];
  const n = Number(amount);
  const submit = picked?.submit
    ?? (picked?.field === "amount" && n > 0 ? `${n.toLocaleString("ko-KR")}코인 ${picked.key === "revoke_coins" ? "회수" : "지급"}` : picked?.label.replace(/ \(사유 필수\)$/, ""));

  return (
    <div className={look === "rows" ? "act-list" : "reason"}>
      {look === "rows"
        ? groups.map((g) => (
          <div key={g || "-"} className="act-group">
            {g && <span>{g}</span>}
            {buttons.filter((b) => (b.group ?? "") === g).map(trigger)}
          </div>
        ))
        : <div className="actions">{buttons.map(trigger)}</div>}
      {state?.ok && !(state.secret && picked?.result) && <p className="faint" role="status">{state.ok}</p>}
      {state?.secret && !picked?.result && <p className="secret">{state.secret}</p>}
      <dialog ref={dialog} className="card" aria-labelledby="reason-title">
        <form key={picked?.key} ref={form} onSubmit={(e) => { e.preventDefault(); const f = new FormData(e.currentTarget); startTransition(() => run(f)); }}>
          <h2 id="reason-title">{picked?.title ?? picked?.label.replace(/ \(사유 필수\)$/, "")}</h2>
          {picked?.details && <dl className="rows">{picked.details.map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v}</dd></div>)}</dl>}
          {picked?.confirm && <p className="notice">{picked.confirm}</p>}
          <input type="hidden" name="action" value={picked?.key ?? ""} />
          {picked?.field === "amount" && <label className="field"><span>{picked.key === "revoke_coins" ? "회수할 코인" : "지급할 코인"} (1~10,000)</span><input name="amount" type="number" min={1} max={10000} required value={amount} onChange={(e) => setAmount(e.target.value)} /></label>}
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
            <button type="button" className="btn-text" onClick={() => dialog.current?.close()}>취소</button>
            <button className={`btn ${picked?.danger ? "btn-danger" : "btn-primary"}`} disabled={pending}>{pending ? "처리하는 중…" : submit}</button>
          </div>
        </form>
      </dialog>
      {picked?.result && (
        <dialog ref={result} className="card" aria-labelledby="result-title">
          <h2 id="result-title">{picked.result.title}</h2>
          {state?.ok && <p className="muted">{state.ok}</p>}
          <input className="copy-field" readOnly value={state?.secret ?? ""} aria-label={picked.result.title} onFocus={(e) => e.currentTarget.select()} />
          {picked.result.note && <p className="faint">{picked.result.note}</p>}
          <div className="dialog-actions">
            <button type="button" className="btn-text" onClick={() => result.current?.close()}>닫기</button>
            <CopyButton text={state?.secret ?? ""} label={picked.result.copy} />
          </div>
        </dialog>
      )}
    </div>
  );
}

function CopyButton({ text, label }: { text: string; label: string }) {
  const [done, setDone] = useState(false);
  return (
    <button type="button" className="btn btn-primary" onClick={() => navigator.clipboard.writeText(text).then(() => setDone(true), () => setDone(false))}>
      {done ? "복사했어요" : label}
    </button>
  );
}
