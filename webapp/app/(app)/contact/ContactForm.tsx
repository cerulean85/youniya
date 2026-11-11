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
      <div className={styles.card} role="status">
        <h2 className="h2">문의를 받았어요</h2>
        <p className="body-m muted">적어 주신 이메일로 답장을 보내 드릴게요. 보통 하루 안에 답해요.</p>
      </div>
    );
  }
  return (
    <form action={action} className={styles.card}>
      {/* Figma Web 시안 v2 · 문의하기 (597:30827): labelled fields on the sky; only the inputs keep a box. */}
      <label className={styles.field}><span className="v2-group">종류</span>
        <select name="kind" defaultValue="other">
          <option value="payment">결제 · 코인</option>
          <option value="account">계정</option>
          <option value="other">기타</option>
        </select>
      </label>
      <label className={styles.field}><span className="v2-group">답장 받을 이메일</span><input name="email" type="email" required autoComplete="email" placeholder="you@example.com" value={email} onChange={(e) => setEmail(e.target.value)} /></label>
      <label className={styles.field}><span className="v2-group">내용</span><textarea name="body" rows={8} maxLength={5000} required value={body} onChange={(e) => setBody(e.target.value)} placeholder="어떤 일이 있었는지 적어 주세요. 결제 문의면 결제한 날짜와 금액을 함께 적어 주시면 빨라요." /></label>
      {state?.error && <p className="body-s" role="alert" style={{ color: "var(--anger)" }}>{state.error}</p>}
      <div className={styles.foot}>
        <p className="v2-small">답장을 위해 이메일과 문의 내용, 브라우저 종류를 받아요. 쓴 글이나 별은 함께 보내지 않아요.</p>
        <Send />
      </div>
      <p className={styles.crisis}>마음이 많이 힘든 날에는<br />24시간 상담 전화 109로 연락해 주세요.</p>
    </form>
  );
}

function Send() {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary" style={{ minWidth: 128, height: 48 }} disabled={pending}>{pending ? "보내는 중…" : "보내기"}</button>;
}
