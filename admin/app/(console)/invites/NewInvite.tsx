"use client";

import { useActionState, useRef } from "react";
import { useFormStatus } from "react-dom";
import { newInvite } from "../owner-actions";

// 새 초대 계정: the password is shown once, here; copy it to the place the reviewer reads it.
export function NewInvite() {
  const [state, action] = useActionState(newInvite, null);
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" className="btn btn-primary" onClick={() => dialog.current?.showModal()}>새 초대 계정</button>
      <dialog ref={dialog} className="card" aria-labelledby="invite-title">
        {state?.password ? (
          <div className="stack">
            <h2 id="invite-title">초대 계정을 만들었어요</h2>
            <p className="muted">아이디 {state.loginId}의 비밀번호예요. 지금 한 번만 보여요.</p>
            <p className="secret">{state.password}</p>
            <button type="button" className="btn" onClick={() => dialog.current?.close()}>닫기</button>
          </div>
        ) : (
          <form action={action}>
            <h2 id="invite-title">새 초대 계정</h2>
            <label className="field"><span>아이디 (영문 소문자·숫자·- 4~20자)</span><input name="login_id" required pattern="[a-z0-9\-]{4,20}" /></label>
            <label className="field"><span>메모</span><input name="memo" placeholder="App Store 심사용" /></label>
            <label className="field"><span>사유 (필수 · 운영 기록에 남아요)</span><textarea name="reason" rows={2} required /></label>
            {state?.error && <p className="error" role="alert">{state.error}</p>}
            <div className="dialog-actions">
              <button type="button" className="btn" onClick={() => dialog.current?.close()}>취소</button>
              <Submit />
            </div>
          </form>
        )}
      </dialog>
    </>
  );
}

function Submit() {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary" disabled={pending}>{pending ? "만드는 중…" : "만들기"}</button>;
}
