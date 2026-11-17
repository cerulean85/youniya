"use client";

import { useActionState, useEffect, useRef, useState, startTransition } from "react";
import { ACTION_LABEL, type ActionKind, type ReportKind } from "@/lib/types";
import { takeAction, type ActState } from "./actions";

const DANGER: ActionKind[] = ["take_down", "restrict_7d", "restrict_30d"];
const GROUPS: [string, ActionKind[]][] = [
  ["이 별", ["take_down", "restore"]],
  ["이 별지기", ["request_rename", "restrict_7d", "restrict_30d"]],
  ["기록만", ["note"]],
];
const OPTION_LABEL: Partial<Record<ActionKind, string>> = { note: "메모 남기기" };

// Figma A2-03 조치: pick one action, write the reason, then one button named after the action.
export function ActionPanel({ kind, id, actions, subject }: { kind: ReportKind; id: string; actions: ActionKind[]; subject: string }) {
  const [state, run, pending] = useActionState(takeAction.bind(null, kind, id), null);
  // The choice belongs to the state it was made under: once a newer action succeeds, nothing is picked.
  const [choice, setChoice] = useState<{ a: ActionKind; under: ActState } | null>(null);
  const picked = choice && (choice.under === state || !state?.ok) ? choice.a : null;
  const form = useRef<HTMLFormElement>(null);
  const handled = useRef<ActState>(null);

  // Clear only after it worked; on an error the choice and the reason stay.
  useEffect(() => {
    if (!state || state === handled.current) return;
    handled.current = state;
    if (state.ok) form.current?.reset();
  }, [state]);

  const label = (a: ActionKind) => OPTION_LABEL[a] ?? ACTION_LABEL[a];
  return (
    <form ref={form} onSubmit={(e) => { e.preventDefault(); const f = new FormData(e.currentTarget); startTransition(() => run(f)); }}>
      {GROUPS.map(([g, list]) => {
        const shown = list.filter((a) => actions.includes(a));
        if (!shown.length) return null;
        return (
          <fieldset key={g} className="opt-group">
            <legend>{g === "이 별" ? subject : g}</legend>
            {shown.map((a) => (
              <label key={a} className={`opt${DANGER.includes(a) ? " danger" : ""}`}>
                <input type="radio" name="action" value={a} checked={picked === a} onChange={() => setChoice({ a, under: state })} required />
                {label(a)}
              </label>
            ))}
          </fieldset>
        );
      })}
      <label className="field"><span>사유 (필수 · 운영 기록에 남아요)</span><textarea name="reason" rows={3} required /></label>
      {picked && picked !== "note" && <label className="field"><span>메모 (선택)</span><input name="note" /></label>}
      {state?.error && <p className="error" role="alert">{state.error}</p>}
      {state?.ok && !picked && <p className="ok-text" role="status">{state.ok} 별지기에게 앱 알림이 가고 운영 기록에 남았어요.</p>}
      <button className={`btn btn-block ${picked && DANGER.includes(picked) ? "btn-danger" : "btn-primary"}`} disabled={pending || !picked}>
        {pending ? "처리하는 중…" : picked ? label(picked) : "조치를 골라 주세요"}
      </button>
      <p className="faint">별지기에게 앱 알림이 가고 운영 기록에 남아요.</p>
    </form>
  );
}
