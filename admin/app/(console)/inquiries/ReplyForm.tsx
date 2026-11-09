"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { sendReply } from "./actions";

export function ReplyForm({ id }: { id: string }) {
  const [state, action] = useActionState(sendReply.bind(null, id), null);
  return (
    <form action={action} className="reply stack" key={state?.ok ? "sent" : "draft"}>
      <label className="field"><span>답장 (문의할 때 적은 이메일로 보내져요)</span><textarea name="body" placeholder="답장 쓰기…" required /></label>
      {state?.error && <p className="error" role="alert">{state.error}</p>}
      {state?.ok && <p className="faint" role="status">답장을 보냈어요. 운영 기록에 남았어요.</p>}
      <Send />
    </form>
  );
}

function Send() {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary" style={{ alignSelf: "flex-start" }} disabled={pending}>{pending ? "보내는 중…" : "답장 보내기"}</button>;
}
