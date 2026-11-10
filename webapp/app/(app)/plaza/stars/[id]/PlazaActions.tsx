"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useActionState, useEffect, useOptimistic, useRef, useState, useSyncExternalStore, useTransition } from "react";
import { useFormStatus } from "react-dom";
import { Close, Heart, More, Warn } from "@/components/icons";
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

export function PlazaActions({ id, resonated, keeper, lines, name = null, mine = false, restricted = false }: { id: string; resonated: boolean; beside: boolean; keeper: string | null; lines: Lines; name?: string | null; mine?: boolean; restricted?: boolean }) {
  const router = useRouter();
  // Mobile PlazaStar: while the plaza is paused for me, 공명 and 건네기 dim and open the note about it instead.
  const paused = () => router.push("/plaza?restricted=1");
  const [on, setOn] = useOptimistic(resonated);
  const [, start] = useTransition();
  const report = useRef<HTMLDialogElement>(null);
  const block = useRef<HTMLDialogElement>(null);
  const line = useRef<HTMLDialogElement>(null);

  return (
    <>
      {!mine && <MoreMenu onReport={() => report.current?.showModal()} onBlock={() => block.current?.showModal()} />}
      <div className={styles.actions}>
        <button type="button" className={`btn ${on ? styles.on : "btn-secondary"}`} aria-pressed={on} data-paused={restricted || undefined}
          onClick={() => restricted ? paused() : start(async () => { setOn(!on); await toggleResonance(id, !on); })}>
          <Heart size={16} />{on ? "공명했어요" : "공명 남기기"}
        </button>
        {keeper ? <Link href={keeper} className="btn btn-primary">이 별지기의 밤하늘 보기</Link> : <span />}
      </div>
      {/* 107: once left, or when the owner doesn't take lines, a dim note instead of the button. */}
      {/* Mobile StarLine: the line I sent stays on this device, so it can be shown again. */}
      {lines === "left" && <SentLine id={id} />}
      {lines === "open" ? (
        <button type="button" className={styles.lineButton} data-paused={restricted || undefined} onClick={() => restricted ? paused() : line.current?.showModal()}>✦ 별빛 한 줄 건네기</button>
      ) : (
        <p className={`caption faint ${styles.lineNote}`}>{lines === "left" ? "이 별에는 이미 한 줄을 건넸어요" : "이 별은 별빛 한 줄을 받지 않아요"}</p>
      )}
      {!mine && (
        <div className={styles.more}>
          <button type="button" onClick={() => report.current?.showModal()}>신고하기</button>
          <button type="button" onClick={() => block.current?.showModal()}>이 별지기 차단</button>
        </div>
      )}

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

      {/* Figma W-95. */}
      <dialog ref={block} className="card sheet" aria-labelledby="block-title">
        <form action={blockOwner.bind(null, id)}>
          <h2 id="block-title" className="h3">{name ? `${name}${/[가-힣]/.test(name.slice(-1)) && (name.charCodeAt(name.length - 1) - 0xac00) % 28 ? "을" : "를"}` : "이 별지기를"} 차단할까요?</h2>
          <p className="body-s muted">차단하면 이 사람의 별과 별빛 한 줄이 내 화면에 더 이상 보이지 않아요. 상대에게는 알리지 않고, 설정 › 차단한 별지기에서 언제든 풀 수 있어요.</p>
          <BlockSubmit />
          <button type="button" className="btn btn-secondary btn-block" onClick={() => block.current?.close()}>취소</button>
        </form>
      </dialog>
    </>
  );
}

// Figma W-94 (Mobile 75 ··· , 14.4): the top-right ··· opens 신고 and 차단; not on my own star.
function MoreMenu({ onReport, onBlock }: { onReport: () => void; onBlock: () => void }) {
  const [open, setOpen] = useState(false);
  const wrap = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const away = (e: PointerEvent) => { if (!wrap.current?.contains(e.target as Node)) setOpen(false); };
    const esc = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
    document.addEventListener("pointerdown", away);
    document.addEventListener("keydown", esc);
    return () => { document.removeEventListener("pointerdown", away); document.removeEventListener("keydown", esc); };
  }, [open]);
  const pick = (run: () => void) => () => { setOpen(false); run(); };
  return (
    <div ref={wrap} className={styles.menuWrap}>
      <button type="button" className={styles.menuButton} aria-label="더 보기" aria-haspopup="menu" aria-expanded={open} onClick={() => setOpen((o) => !o)}>
        <More size={18} />
      </button>
      {open && (
        <div role="menu" className={styles.menu}>
          <button type="button" role="menuitem" onClick={pick(onReport)}>
            <span className={styles.menuIcon}><Warn size={16} /></span>
            <span><b>이 별 신고하기</b><small>운영팀이 살펴봐요</small></span>
          </button>
          <button type="button" role="menuitem" className={styles.menuDanger} onClick={pick(onBlock)}>
            <span className={styles.menuIcon}><Close size={16} /></span>
            <span><b>이 별지기 차단하기</b><small>이 사람의 글이 더 보이지 않아요</small></span>
          </button>
        </div>
      )}
    </div>
  );
}

// Figma W-55: a quick chip, or up to 60 characters; checked for hurtful words, contacts and advice before it goes.
const sentKey = (id: string) => `yn_line_${id}`;
const onStorage = (change: () => void) => { window.addEventListener("storage", change); return () => window.removeEventListener("storage", change); };

function SentLine({ id }: { id: string }) {
  const sent = useSyncExternalStore(onStorage, () => { try { return localStorage.getItem(sentKey(id)); } catch { return null; } }, () => null);
  if (!sent) return null;
  return <div className={styles.sentLine}><span className="caption faint">내가 건넨 한 줄</span><p className="body-s">{sent}</p></div>;
}

function LineForm({ id, onDone }: { id: string; onDone: () => void }) {
  const [state, action] = useActionState(leaveLine.bind(null, id), null);
  const [text, setText] = useState("");
  useEffect(() => { if (state?.ok && state.sent) try { localStorage.setItem(sentKey(id), state.sent); } catch { /* private mode */ } }, [state, id]);
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

function BlockSubmit() {
  const { pending } = useFormStatus();
  return <button className="btn btn-danger btn-block" disabled={pending}>{pending ? "차단하는 중…" : "차단하기"}</button>;
}
