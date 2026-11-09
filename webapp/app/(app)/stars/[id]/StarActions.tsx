"use client";

import Link from "next/link";
import { useActionState, useRef } from "react";
import { useFormStatus } from "react-dom";
import { deleteStar, floatStar } from "./actions";
import styles from "./star.module.css";

export function FloatButton({ id }: { id: string }) {
  const [state, action] = useActionState(floatStar.bind(null, id), null);
  return (
    <form action={action} className={styles.floatForm}>
      <Pending label="별빛 받기" busy="별빛 프리즘이 비추는 중…" />
      {state?.error && (
        <p className="body-s" role="alert">
          {state.error} {state.code === "insufficient_coins" && <Link href="/coins" className={styles.link}>코인 충전하기</Link>}
        </p>
      )}
    </form>
  );
}

function Pending({ label, busy }: { label: string; busy: string }) {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary btn-block" disabled={pending}>{pending ? busy : label}</button>;
}

// Figma W-37: deleting asks first; it can't be undone.
export function DeleteButton({ id, title }: { id: string; title: string }) {
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" className="btn btn-ghost" onClick={() => dialog.current?.showModal()}>삭제</button>
      <dialog ref={dialog} className={`card ${styles.dialog}`} aria-labelledby="del-title">
        <form action={deleteStar.bind(null, id)}>
          <h2 id="del-title" className="h2">이 별을 지울까요?</h2>
          <p className="body-m muted">“{title}”의 글과 분석, 우주 광장에 나눈 문장이 함께 사라져요. 지운 별은 되살릴 수 없어요.</p>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => dialog.current?.close()}>취소</button>
            <DeleteSubmit />
          </div>
        </form>
      </dialog>
    </>
  );
}

function DeleteSubmit() {
  const { pending } = useFormStatus();
  return <button className={`btn ${styles.danger}`} disabled={pending}>{pending ? "지우는 중…" : "영구 삭제"}</button>;
}
