"use client";

import { useActionState, useRef, useState } from "react";
import { useFormStatus } from "react-dom";
import { ACTION_LABEL, type ActionKind, type ReportKind } from "@/lib/types";
import { takeAction } from "./actions";

const DANGER: ActionKind[] = ["take_down", "restrict_7d", "restrict_30d"];

// Figma A-04 조치: each button opens a reason box; nothing happens without a reason.
export function ActionPanel({ kind, id, actions }: { kind: ReportKind; id: string; actions: ActionKind[] }) {
  const [state, action] = useActionState(takeAction.bind(null, kind, id), null);
  const [picked, setPicked] = useState<ActionKind | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const open = (a: ActionKind) => { setPicked(a); dialog.current?.showModal(); };
  return (
    <>
      <div className="actions">
        {actions.map((a) => (
          <button key={a} type="button" className={`btn ${DANGER.includes(a) ? "btn-danger" : ""}`} onClick={() => open(a)}>{ACTION_LABEL[a]}</button>
        ))}
      </div>
      {state?.ok && <p className="faint" role="status">{state.ok} 별지기에게 앱 알림이 가고 운영 기록에 남았어요.</p>}
      <dialog ref={dialog} className="card" aria-labelledby="act-title">
        <form action={async (f) => { await action(f); dialog.current?.close(); }}>
          <h2 id="act-title">{picked ? ACTION_LABEL[picked] : ""}</h2>
          <input type="hidden" name="action" value={picked ?? ""} />
          <label className="field"><span>사유 (필수 · 운영 기록에 남아요)</span><textarea name="reason" rows={3} required /></label>
          {picked !== "note" && <label className="field"><span>메모 (선택)</span><input name="note" /></label>}
          {state?.error && <p className="error" role="alert">{state.error}</p>}
          <div className="dialog-actions">
            <button type="button" className="btn" onClick={() => dialog.current?.close()}>취소</button>
            <Submit danger={picked ? DANGER.includes(picked) : false} />
          </div>
        </form>
      </dialog>
    </>
  );
}

function Submit({ danger }: { danger: boolean }) {
  const { pending } = useFormStatus();
  return <button className={`btn ${danger ? "btn-danger" : "btn-primary"}`} disabled={pending}>{pending ? "처리하는 중…" : "조치하기"}</button>;
}
