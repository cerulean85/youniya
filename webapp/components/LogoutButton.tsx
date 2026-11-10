"use client";

import { useRef } from "react";

// Figma W-98 (Mobile 87-5): signing out asks first; nothing written goes anywhere.
export function LogoutButton({ className, children }: { className?: string; children: React.ReactNode }) {
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" className={className} onClick={() => dialog.current?.showModal()}>{children}</button>
      <dialog ref={dialog} className="card sheet" aria-labelledby="logout-title">
        <form action="/auth/logout" method="post">
          <h2 id="logout-title" className="h3">로그아웃할까요?</h2>
          <p className="body-s muted">쓴 글과 별은 그대로 남아 있어요. 다시 로그인하면 이어서 볼 수 있어요.</p>
          <button className="btn btn-primary btn-block">로그아웃</button>
          <button type="button" className="btn btn-secondary btn-block" onClick={() => dialog.current?.close()}>취소</button>
        </form>
      </dialog>
    </>
  );
}
