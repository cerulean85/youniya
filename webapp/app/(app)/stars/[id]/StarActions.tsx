"use client";

import { CoinsLink } from "@/components/CoinsLink";
import { Toast } from "@/components/Flash";
import Link from "next/link";
import { useActionState, useRef, useState } from "react";
import { useFormStatus } from "react-dom";
import { Close } from "@/components/icons";
import { PrismOverlay } from "@/components/PrismOverlay";
import { moodOf, monthDay } from "@/lib/format";
import type { LinkedStar } from "@/lib/types";
import { deleteStar, floatStar, unlinkStar } from "./actions";
import styles from "./star.module.css";

// Figma W-56: 별빛 받기 asks first, since the writing locks; W-23 shows while the prism reads it.
export function FloatButton({ id, free, coins }: { id: string; free: boolean; coins: number }) {
  const [state, action] = useActionState(floatStar.bind(null, id), null);
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" className="btn btn-primary btn-block" onClick={() => dialog.current?.showModal()}>별빛 받기</button>
      <dialog ref={dialog} className={`card ${styles.dialog}`} aria-labelledby="light-title">
        <form action={action}>
          <h2 id="light-title" className="h2">이 별에 별빛을 받을까요?</h2>
          <p className="body-m muted">별빛 프리즘이 글을 읽고 별빛·깊이·고유한 별 모양과 별빛 풀이를 줘요. {free ? "오늘 무료 1번 남았어요." : `5코인이 들어요 (보유 ${coins}).`}</p>
          <p className="body-m muted">별빛을 받으면 이 글은 잠겨서 고칠 수 없어요. 고치고 싶은 곳이 있으면 먼저 고친 뒤 받아 주세요.</p>
          {state?.error && (
            <p className="body-s" role="alert">
              {state.error} {state.code === "insufficient_coins" && <CoinsLink className={styles.link}>코인 충전하기</CoinsLink>}
            </p>
          )}
          <Pending label={free ? "별빛 받기 · 오늘 무료 1번" : "별빛 받기 · 5코인"} busy="별빛 프리즘이 비추는 중…" />
          <button type="button" className="btn btn-ghost" onClick={() => dialog.current?.close()}>다음에</button>
          <PrismOverlay />
        </form>
      </dialog>
    </>
  );
}

// W-85: '다시 시도' reads it again straight away (nothing was charged the first time).
export function RetryFloat({ id }: { id: string }) {
  const [state, action] = useActionState(floatStar.bind(null, id), null);
  return (
    <form action={action} style={{ display: "contents" }}>
      {state?.error && <p className="body-s" role="alert">{state.error} {state.code === "insufficient_coins" && <CoinsLink className={styles.link}>코인 충전하기</CoinsLink>}</p>}
      <Pending label="다시 시도" busy="별빛 프리즘이 비추는 중…" />
      <PrismOverlay />
    </form>
  );
}

export { Toast } from "@/components/Flash";

function Pending({ label, busy, secondary }: { label: string; busy: string; secondary?: boolean }) {
  const { pending } = useFormStatus();
  return <button className={`btn ${secondary ? "btn-secondary" : "btn-primary"} btn-block`} disabled={pending}>{pending ? busy : label}</button>;
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


// 내보내기: the writing as a text file, made in the browser.
export function ExportButton({ title, date, body }: { title: string; date: string; body: string }) {
  const [done, setDone] = useState(0);
  const save = () => {
    const url = URL.createObjectURL(new Blob([`${title}\n${date}\n\n${body}\n`], { type: "text/plain;charset=utf-8" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = `${title.replace(/[\\/:*?"<>|]/g, "").trim() || "별"}.txt`;
    a.click();
    URL.revokeObjectURL(url);
    setDone((n) => n + 1);
  };
  return <><button type="button" className="btn btn-ghost" onClick={save}>내보내기</button>{done > 0 && <Toast key={done} title="파일로 내보냈어요" />}</>;
}

// 이어진 별 chips: open the star, or cut the link (W-47 "언제든 끊을 수 있어요").
export function LinkedChip({ id, star }: { id: string; star: LinkedStar }) {
  return (
    <span className={styles.chip} style={{ ["--c" as string]: moodOf(star.mood).color }}>
      <Link href={`/stars/${star.id}`}>
        <span className="label-s">{star.title || "제목 없는 별"}</span>
        <span className="caption faint">{monthDay(star.created_at)}{star.has_starlight ? "" : " · 별빛 없는 별"}</span>
      </Link>
      <form action={unlinkStar.bind(null, id, star.id)}>
        <button className={styles.unlink} aria-label={`${star.title} 잇기 끊기`} title="잇기 끊기"><Close size={12} /></button>
      </form>
    </span>
  );
}
