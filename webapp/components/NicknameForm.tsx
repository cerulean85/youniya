"use client";

import { useActionState, useEffect, useState, useTransition } from "react";
import { useFormStatus } from "react-dom";
import { checkNickname, saveNickname, type NameCheck } from "@/app/nickname/actions";
import styles from "./NicknameForm.module.css";

const FORM = /^[가-힣a-zA-Z0-9]{2,12}$/;

// Figma W-49 (21-1): checked as it's typed, saved once it's free. Also used in 설정.
export function NicknameForm({ initial = "", next = "/", submit = "이 이름으로 시작하기" }: { initial?: string; next?: string; submit?: string }) {
  const [name, setName] = useState(initial);
  const [check, setCheck] = useState<NameCheck | null>(null);
  const [checking, start] = useTransition();
  const [state, action] = useActionState(saveNickname, null);
  const trimmed = name.trim();
  const formOk = FORM.test(trimmed);

  useEffect(() => {
    if (!formOk || trimmed === initial) return;
    const t = setTimeout(() => start(async () => setCheck({ ...(await checkNickname(trimmed)) })), 350);
    return () => clearTimeout(t);
  }, [trimmed, formOk, initial]);

  const current = check && formOk;
  const status = !trimmed ? null
    : !formOk ? { ok: false, text: "2~12자, 한글·영문·숫자로 정해 주세요." }
    : initial && trimmed === initial ? { ok: null, text: "지금 쓰고 있는 이름이에요." }
    : checking || !current ? { ok: null, text: "확인하는 중…" }
    : check.available ? { ok: true, text: `쓸 수 있는 이름이에요 · ${trimmed.length}/12` }
    : { ok: false, text: check.message ?? "쓸 수 없는 이름이에요." };

  return (
    <form action={action} className={styles.form}>
      <input type="hidden" name="next" value={next} />
      <label className={styles.field}>
        <span className="label-s muted">별지기 이름</span>
        <input name="name" value={name} onChange={(e) => { setName(e.target.value); setCheck(null); }} maxLength={12}
          autoComplete="off" spellCheck={false} placeholder="느린고래" aria-describedby="name-status" />
      </label>
      <p id="name-status" className={styles.status} data-ok={status?.ok ?? undefined} role="status">{status?.text ?? " "}</p>
      <ul className={styles.rules}>
        <li>2~12자, 한글·영문·숫자로 정해요.</li>
        <li>다른 별지기와 겹칠 수 없어요.</li>
        <li>실명이나 연락처는 쓰지 않는 게 좋아요.</li>
        <li>30일에 한 번 바꿀 수 있어요.</li>
      </ul>
      {state?.error && <p className="body-s" role="alert">{state.error}</p>}
      <Save label={submit} disabled={!(status?.ok === true)} />
    </form>
  );
}

function Save({ label, disabled }: { label: string; disabled: boolean }) {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary btn-block" disabled={disabled || pending}>{pending ? "정하는 중…" : label}</button>;
}
