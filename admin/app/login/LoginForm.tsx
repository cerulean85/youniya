"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { signIn } from "./actions";

export function LoginForm() {
  const [state, action] = useActionState(signIn, null);
  const code = state?.step === "code";
  return (
    <form action={action} className="login-form">
      {code ? (
        <label className="field" key="code">
          <span>인증 앱 6자리</span>
          <input name="code" inputMode="numeric" autoComplete="one-time-code" pattern="\d{6}" maxLength={6} required autoFocus />
        </label>
      ) : (
        <>
          <label className="field"><span>이메일</span><input name="email" type="email" autoComplete="username" required autoFocus /></label>
          <label className="field"><span>비밀번호</span><input name="password" type="password" autoComplete="current-password" required /></label>
        </>
      )}
      {state?.error && <p className="error" role="alert">{state.error}</p>}
      <Submit label={code ? "확인" : "다음"} />
      <p className="faint">{code ? "인증 앱의 YOUNIYA 운영자 코드를 넣어 주세요." : "5번 틀리면 15분 동안 잠겨요. 모든 로그인은 운영 기록에 남아요."}</p>
    </form>
  );
}

function Submit({ label }: { label: string }) {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary btn-block" disabled={pending}>{pending ? "확인하는 중…" : label}</button>;
}
