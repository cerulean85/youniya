"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { setup } from "./actions";

export function SetupForm({ token }: { token: string }) {
  const [state, action] = useActionState(setup, null);
  const totp = state?.step === "totp";
  return (
    <form action={action} className="login-form">
      <input type="hidden" name="token" value={token} />
      {totp ? (
        <>
          <p className="muted">인증 앱(Google Authenticator, 1Password 등)으로 QR을 찍고, 앱에 보이는 6자리를 넣어 주세요.</p>
          <div className="qr" dangerouslySetInnerHTML={{ __html: state.qr ?? "" }} />
          <p className="faint">QR을 못 찍으면 이 키를 직접 넣어요: <code>{state.secret}</code></p>
          <label className="field" key="code"><span>인증 앱 6자리</span><input name="code" inputMode="numeric" autoComplete="one-time-code" pattern="\d{6}" maxLength={6} required autoFocus /></label>
        </>
      ) : (
        <>
          <label className="field"><span>비밀번호 (12자 이상)</span><input name="password" type="password" autoComplete="new-password" minLength={12} required autoFocus /></label>
          <label className="field"><span>비밀번호 확인</span><input name="confirm" type="password" autoComplete="new-password" minLength={12} required /></label>
        </>
      )}
      {state?.error && <p className="error" role="alert">{state.error}</p>}
      <Submit label={totp ? "설정 마치기" : "다음"} />
    </form>
  );
}

function Submit({ label }: { label: string }) {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary btn-block" disabled={pending}>{pending ? "확인하는 중…" : label}</button>;
}
