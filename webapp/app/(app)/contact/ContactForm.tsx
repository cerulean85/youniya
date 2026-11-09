"use client";

import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import { sendInquiry } from "./actions";
import styles from "./contact.module.css";

export function ContactForm() {
  const [state, action] = useActionState(sendInquiry, null);
  // Kept in state so a failed send doesn't clear what was written.
  const [email, setEmail] = useState("");
  const [body, setBody] = useState("");
  if (state?.ok) {
    return (
      <div className={`card ${styles.card}`} role="status">
        <h2 className="h2">문의를 받았어요</h2>
        <p className="body-m muted">적어 주신 이메일로 답장을 보내 드릴게요. 보통 하루 안에 답해요.</p>
      </div>
    );
  }
  return (
    <form action={action} className={`card ${styles.card}`}>
      <fieldset className={styles.kinds}>
        <legend className="label-s muted">문의 유형</legend>
        {[["payment", "결제"], ["account", "계정"], ["other", "기타"]].map(([k, l], i) => (
          <label key={k}><input type="radio" name="kind" value={k} defaultChecked={i === 2} />{l}</label>
        ))}
      </fieldset>
      <label className={styles.field}><span className="label-s muted">답장 받을 이메일</span><input name="email" type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} /></label>
      <label className={styles.field}><span className="label-s muted">내용</span><textarea name="body" rows={8} maxLength={5000} required value={body} onChange={(e) => setBody(e.target.value)} placeholder="어떤 일이 있었는지 적어 주세요. 결제 문의면 결제한 날짜와 금액을 함께 적어 주시면 빨라요." /></label>
      <p className="caption faint">답장을 위해 이메일과 문의 내용, 브라우저 종류를 받아요. 쓴 글이나 별은 함께 보내지 않아요.</p>
      {state?.error && <p className="body-s" role="alert" style={{ color: "var(--anger)" }}>{state.error}</p>}
      <Send />
    </form>
  );
}

function Send() {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary" style={{ alignSelf: "flex-start" }} disabled={pending}>{pending ? "보내는 중…" : "보내기"}</button>;
}
