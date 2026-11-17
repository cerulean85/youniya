"use client";

import Link from "next/link";
import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";
import { inviteSignIn } from "./actions";
import styles from "../login.module.css";

function Submit() {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary btn-block" disabled={pending}>{pending ? "들어가는 중…" : "로그인"}</button>;
}

export function InviteForm() {
  const [state, action] = useActionState(inviteSignIn, null);
  // Kept in state so a failed sign-in doesn't clear what was typed.
  const [login, setLogin] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  return (
    <form action={action} className={styles.invite}>
      <label className={styles.field}><span className="label-m">아이디</span>
        <input name="login" value={login} onChange={(e) => setLogin(e.target.value)} autoComplete="username" autoCapitalize="none" spellCheck={false} maxLength={64} required />
      </label>
      <label className={styles.field}><span className="label-m">비밀번호</span>
        <span className={styles.pw}>
          <input name="password" type={show ? "text" : "password"} value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" maxLength={128} required />
          <button type="button" className={styles.reveal} onClick={() => setShow(!show)} aria-pressed={show}>{show ? "숨기기" : "보기"}</button>
        </span>
      </label>
      {state?.error && <p className={`body-s ${styles.error}`} role="alert">{state.error}</p>}
      <Submit />
      <Link href="/login" className="btn btn-ghost btn-block">취소</Link>
    </form>
  );
}
