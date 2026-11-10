"use client";

import Link from "next/link";
import { useRef, useState, useTransition } from "react";
import { useFormStatus } from "react-dom";
import { Info, Lock } from "@/components/icons";
import { scanBody, scanSentences, shareStar, unshareStar } from "./actions";
import styles from "./star.module.css";

type Option = { text: string; masked: string; total: number };

// The server counts every contact as one kind; the same patterns split them for the W-75 card.
const PHONE = /(?<!\d)0\d{1,2}[-. ]?\d{3,4}[-. ]?\d{4}(?!\d)/g;
const EMAIL = /[\w.+-]+@[\w-]+\.[A-Za-z.]+/g;
function breakdown(body: string, total: number) {
  const phone = body.match(PHONE)?.length ?? 0, email = body.match(EMAIL)?.length ?? 0;
  const other = Math.max(0, total - phone - email);
  return [["전화번호", phone], ["이메일", email], ["계좌·카드번호", other]].filter(([, n]) => n).map(([k, n]) => `${k} ${n}`).join(" · ");
}

function sentencesOf(body: string) {
  return body.split(/(?<=[.!?。…])\s+|\n+/).map((s) => s.trim()).filter((s) => s.length >= 4 && s.length <= 300).slice(0, 12);
}

// Figma W-26 (기획서 15장): the writer picks a 대표 문장; it goes to the plaza with the whole writing and their
// 별지기 이름, contacts masked. A star without starlight can be shared too (17.2).
export function ShareStar({ id, title, body, shared, lit, nickname }: { id: string; title: string; body: string; shared: boolean; lit: boolean; nickname: string | null }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [options, setOptions] = useState<Option[] | null>(null);
  const [check, setCheck] = useState<number | null>(null);
  const [step, setStep] = useState<"check" | "pick">("check");
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
    setStep("check");
    dialog.current?.showModal();
    if (!options) start(async () => {
      const list = sentencesOf(body);
      const [whole, scans] = await Promise.all([scanBody(`${title}\n${body}`), scanSentences(list)]);
      setCheck(whole.total);
      setOptions(list.map((text, i) => ({ text, masked: scans[i].masked, total: scans[i].total })));
    });
  };
  // 15.1: the plaza shows a 별지기 이름, so it's set first.
  if (!nickname) return <Link href={`/nickname?next=${encodeURIComponent(`/stars/${id}`)}`} className="btn btn-secondary btn-block">우주 광장에 나누기</Link>;
  return (
    <>
      <button type="button" className="btn btn-secondary btn-block" onClick={open}>우주 광장에 나누기</button>
      <dialog ref={dialog} className={`card ${styles.dialog} ${styles.shareDialog}`} aria-labelledby={step === "check" ? "check-title" : "share-title"}>
        {/* Figma W-75 (iOS 20): before picking, how the whole writing will go out. */}
        {step === "check" ? (
          <div className={styles.check}>
            <h2 id="check-title" className="h2">나누기 전에 한 번 확인해 주세요</h2>
            <p className="body-s muted">전화번호와 이메일을 가려 두었어요. 이름과 장소는 그대로 보이니 확인하고 나눠 주세요.</p>
            <p className={styles.checkBanner}><Info size={16} />전화번호·이메일·계좌번호는 자동으로 가려져요.</p>
            <div className={styles.checkCard}>
              {check == null ? <span className="body-s faint">글을 살펴보는 중…</span> : check > 0 ? (
                <><span className="label-m">가려진 항목 {check}개</span><span className="body-s muted">{breakdown(`${title}\n${body}`, check)}</span></>
              ) : (
                <><span className="label-m">가려진 항목이 없어요</span><span className="body-s muted">그대로 나눠도 괜찮아 보여요.</span></>
              )}
            </div>
            <button type="button" className="btn btn-primary btn-block" disabled={check == null} onClick={() => setStep("pick")}>확인했어요</button>
            <button type="button" className="btn btn-ghost btn-block" onClick={() => dialog.current?.close()}>취소</button>
          </div>
        ) : (
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
        )}
      </dialog>
    </>
  );
}

function Pending({ label, busy, style, disabled }: { label: string; busy: string; style: string; disabled?: boolean }) {
  const { pending } = useFormStatus();
  return <button className={`btn ${style}`} disabled={pending || disabled}>{pending ? busy : label}</button>;
}
