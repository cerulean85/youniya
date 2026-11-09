"use client";

import Link from "next/link";
import { useActionState, useOptimistic, useRef, useState, useTransition } from "react";
import { useFormStatus } from "react-dom";
import { Heart } from "@/components/icons";
import { LINE_CHIPS } from "@/lib/types";
import { blockOwner, leaveLine, reportShare, toggleResonance } from "./actions";
import styles from "./plaza-star.module.css";

export const REASONS = [
  ["hurtful", "상처를 주는 말이에요"],
  ["personal_info", "개인정보가 드러나 있어요"],
  ["self_harm", "자해나 극단적인 생각이 걱정돼요"],
  ["harassment", "괴롭힘이에요"],
  ["hate", "혐오 표현이에요"],
  ["impersonation", "다른 사람을 사칭해요"],
  ["advertising", "광고나 홍보예요"],
  ["nickname", "별지기 이름이 부적절해요"],
  ["other", "그 밖의 이유가 있어요"],
] as const;

type Lines = "open" | "left" | "closed";

export function PlazaActions({ id, resonated, keeper, lines }: { id: string; resonated: boolean; beside: boolean; keeper: string | null; lines: Lines }) {
  const [on, setOn] = useOptimistic(resonated);
  const [, start] = useTransition();
  const report = useRef<HTMLDialogElement>(null);
  const block = useRef<HTMLDialogElement>(null);
  const line = useRef<HTMLDialogElement>(null);

  return (
    <>
      <div className={styles.actions}>
        <button type="button" className={`btn ${on ? styles.on : "btn-secondary"}`} aria-pressed={on}
          onClick={() => start(async () => { setOn(!on); await toggleResonance(id, !on); })}>
          <Heart size={16} />{on ? "공명했어요" : "공명 남기기"}
        </button>
        {keeper ? <Link href={keeper} className="btn btn-primary">이 별지기의 밤하늘 보기</Link> : <span />}
      </div>
      {lines !== "closed" && (
        <button type="button" className={styles.lineButton} disabled={lines === "left"} onClick={() => line.current?.showModal()}>
          {lines === "left" ? "별빛 한 줄을 건넸어요" : "✦ 별빛 한 줄 건네기"}
        </button>
      )}
      <div className={styles.more}>
        <button type="button" onClick={() => report.current?.showModal()}>신고하기</button>
        <button type="button" onClick={() => block.current?.showModal()}>이 별지기 차단</button>
      </div>

      <dialog ref={line} className={`card ${styles.dialog}`} aria-labelledby="line-title">
        <LineForm id={id} onDone={() => line.current?.close()} />
      </dialog>

      <dialog ref={report} className={`card ${styles.dialog}`} aria-labelledby="report-title">
        <form action={reportShare.bind(null, id)}>
          <h2 id="report-title" className="h2">이 별을 신고할까요?</h2>
          <p className="body-s muted">신고한 별은 바로 가려지고 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요.</p>
          <fieldset className={styles.reasons}>
            <legend className="label-s faint">이유</legend>
            {REASONS.map(([key, label], i) => (
              <label key={key}><input type="radio" name="reason" value={key} defaultChecked={i === 0} />{label}</label>
            ))}
          </fieldset>
          <label className={styles.check}><input type="checkbox" name="block" />이 별지기도 차단하기</label>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => report.current?.close()}>취소</button>
            <Submit label="신고하기" busy="보내는 중…" />
          </div>
        </form>
      </dialog>

      <dialog ref={block} className={`card ${styles.dialog}`} aria-labelledby="block-title">
        <form action={blockOwner.bind(null, id)}>
          <h2 id="block-title" className="h2">이 별지기를 차단할까요?</h2>
          <p className="body-s muted">서로의 별과 별빛 한 줄이 어디에서도 보이지 않아요. 상대에게는 알리지 않고, 설정 › 차단한 별지기에서 풀 수 있어요.</p>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => block.current?.close()}>취소</button>
            <Submit label="차단하기" busy="차단하는 중…" />
          </div>
        </form>
      </dialog>
    </>
  );
}

// Figma W-55: a quick chip, or up to 60 characters; checked for hurtful words, contacts and advice before it goes.
function LineForm({ id, onDone }: { id: string; onDone: () => void }) {
  const [state, action] = useActionState(leaveLine.bind(null, id), null);
  const [text, setText] = useState("");
  if (state?.ok) {
    return (
      <div className={styles.lineDone}>
        <h2 id="line-title" className="h2">별빛 한 줄을 건넸어요</h2>
        <p className="body-s muted">별 주인만 읽을 수 있어요.</p>
        <button type="button" className="btn btn-primary" onClick={onDone}>닫기</button>
      </div>
    );
  }
  return (
    <form action={action} className={styles.lineForm}>
      <h2 id="line-title" className="h2">별빛 한 줄 건네기</h2>
      <p className="caption muted">한 사람이 한 별에 한 줄씩 건넬 수 있어요. 별 주인만 읽을 수 있어요.</p>
      {/* The text row comes first in the markup so Enter sends the text, not the first chip; CSS puts the chips above. */}
      <div className={styles.lineInput}>
        <input name="text" value={text} maxLength={60} onChange={(e) => setText(e.target.value)} placeholder="한 줄을 남겨 보세요 (60자)" aria-label="별빛 한 줄" />
        <span className="caption faint">{text.length}/60</span>
        <SendButton disabled={!text.trim()} />
      </div>
      <div className={styles.chips}>
        {LINE_CHIPS.map((c) => <ChipButton key={c.key} chip={c.key} label={c.label} />)}
      </div>
      {state?.error && <p className="body-s" role="alert" style={{ color: "var(--anger)" }}>{state.error}</p>}
      <p className="caption faint">상처 주는 말은 별빛이 되지 못해요 · 보내기 전에 한 번 걸러요 · 신고</p>
      <button type="button" className="btn btn-ghost" onClick={onDone}>닫기</button>
    </form>
  );
}

function ChipButton({ chip, label }: { chip: string; label: string }) {
  const { pending } = useFormStatus();
  return <button name="chip" value={chip} className={styles.chip} disabled={pending}>{label}</button>;
}

function SendButton({ disabled }: { disabled: boolean }) {
  const { pending } = useFormStatus();
  return <button className={styles.send} disabled={disabled || pending} aria-label="보내기">↑</button>;
}

function Submit({ label, busy }: { label: string; busy: string }) {
  const { pending } = useFormStatus();
  return <button className={`btn ${styles.danger}`} disabled={pending}>{pending ? busy : label}</button>;
}
