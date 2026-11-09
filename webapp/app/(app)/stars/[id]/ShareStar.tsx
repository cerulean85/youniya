"use client";

import Link from "next/link";
import { useRef, useState, useTransition } from "react";
import { useFormStatus } from "react-dom";
import { Lock } from "@/components/icons";
import { scanSentences, shareStar, unshareStar } from "./actions";
import styles from "./star.module.css";

type Option = { text: string; masked: string; total: number };

function sentencesOf(body: string) {
  return body.split(/(?<=[.!?。…])\s+|\n+/).map((s) => s.trim()).filter((s) => s.length >= 4 && s.length <= 300).slice(0, 12);
}

// Figma W-26 (기획서 15장): the writer picks a 대표 문장; it goes to the plaza with the whole writing and their
// 별지기 이름, contacts masked. A star without starlight can be shared too (17.2).
export function ShareStar({ id, title, body, shared, lit, nickname }: { id: string; title: string; body: string; shared: boolean; lit: boolean; nickname: string | null }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [options, setOptions] = useState<Option[] | null>(null);
  const [loading, start] = useTransition();

  if (shared) {
    return (
      <form action={unshareStar.bind(null, id)} className={styles.shared}>
        <span className="body-s muted">우주 광장에 {nickname ?? "별지기"} 이름으로 나눈 별이에요.</span>
        <Pending label="광장에서 내리기" busy="내리는 중…" style="btn-ghost" />
      </form>
    );
  }
  const open = () => {
    dialog.current?.showModal();
    if (!options) start(async () => {
      const list = sentencesOf(body);
      const scans = await scanSentences(list);
      setOptions(list.map((text, i) => ({ text, masked: scans[i].masked, total: scans[i].total })));
    });
  };
  // 15.1: the plaza shows a 별지기 이름, so it's set first.
  if (!nickname) return <Link href={`/nickname?next=${encodeURIComponent(`/stars/${id}`)}`} className="btn btn-secondary btn-block">우주 광장에 나누기</Link>;
  return (
    <>
      <button type="button" className="btn btn-secondary btn-block" onClick={open}>우주 광장에 나누기</button>
      <dialog ref={dialog} className={`card ${styles.dialog} ${styles.shareDialog}`} aria-labelledby="share-title">
        <form action={async (f) => { await shareStar(id, f); dialog.current?.close(); }}>
          <p className="caption faint">{title}</p>
          <h2 id="share-title" className="h2">어떤 문장을 나눌까요?</h2>
          <p className="body-s muted">고른 대표 문장과 글 전체가 별지기 이름({nickname})과 함께 올라가요. 전화번호·이메일은 ●●●로 가려져요.</p>
          {!lit && <p className="caption" style={{ color: "var(--gold)" }}>별빛 없는 별은 목록 아래쪽에 놓여요. 별빛을 받으면 더 많은 사람에게 닿아요.</p>}
          <div className={styles.options} role="radiogroup">
            {loading || !options ? <p className="body-s faint">문장을 살펴보는 중…</p> : options.length === 0 ? (
              <p className="body-s faint">나눌 만한 문장을 찾지 못했어요.</p>
            ) : options.map((o, i) => (
              <label key={i} className={styles.option}>
                <input type="radio" name="quote" value={o.text} defaultChecked={i === 0} />
                <span>
                  <span className="observation">“{o.masked}”</span>
                  {o.total > 0 && <span className={styles.masked}><Lock size={14} />{o.total}곳을 가린 채로 올라가요</span>}
                </span>
              </label>
            ))}
          </div>
          <label className={styles.receive}><input type="checkbox" name="receive_lines" defaultChecked />별빛 한 줄 받기 · 나만 읽을 수 있어요</label>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => dialog.current?.close()}>취소</button>
            <Pending label="이 문장으로 나누기" busy="나누는 중…" style="btn-primary" disabled={!options?.length} />
          </div>
        </form>
      </dialog>
    </>
  );
}

function Pending({ label, busy, style, disabled }: { label: string; busy: string; style: string; disabled?: boolean }) {
  const { pending } = useFormStatus();
  return <button className={`btn ${style}`} disabled={pending || disabled}>{pending ? busy : label}</button>;
}
