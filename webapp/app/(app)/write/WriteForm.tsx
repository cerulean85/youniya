"use client";

import { CoinsLink } from "@/components/CoinsLink";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useActionState, useEffect, useRef, useState } from "react";
import { useFormStatus } from "react-dom";
import { Info, Lock } from "@/components/icons";
import { FlashToast, OfflineBanner, useOnline } from "@/components/Offline";
import { AttemptField, freshAttempt, PrismOverlay } from "@/components/PrismOverlay";
import { MIN_FLOAT_LENGTH, MOODS } from "@/lib/format";
import type { Draft, Mood } from "@/lib/types";
import { createStar, saveDraft } from "./actions";
import styles from "./write.module.css";

const STAR_COST = 5;

/** The star a 고쳐 쓰기 starts from, or the one a 별 잇기 joins the new star to. */
export type Source = { kind: "rewrite" | "link"; id: string; title: string; question: string | null; moods: Mood[]; body: string };

export function WriteForm({ draft, source, freeStarToday, coins }: { draft: Draft; source: Source | null; freeStarToday: number; coins: number }) {
  const rewrite = source?.kind === "rewrite" ? source : null;
  // 고쳐 쓰기 starts from the old writing unless a draft of it is waiting.
  const start = draft ?? (rewrite && { mood: rewrite.moods[0], moods: rewrite.moods, title: rewrite.title, body: rewrite.body });
  // Several moods in the order picked; the first is the star's colour (기획서 17.1).
  const [moods, setMoods] = useState<Mood[]>(start?.moods?.length ? start.moods : [start?.mood ?? "calm"]);
  const toggleMood = (m: Mood) => setMoods((list) => (list.includes(m) ? (list.length > 1 ? list.filter((x) => x !== m) : list) : [...list, m]));
  const confirm = useRef<HTMLDialogElement>(null);
  const shortage = useRef<HTMLDialogElement>(null);
  const leave = useRef<HTMLDialogElement>(null);
  const [leaveTo, setLeaveTo] = useState("/");
  const router = useRouter();
  const [title, setTitle] = useState(start?.title ?? "");
  const [body, setBody] = useState(start?.body ?? "");
  const [saved, setSaved] = useState<string | null>(draft ? "이전에 쓰던 글을 불러왔어요" : null);
  const [state, action] = useActionState(createStar, null);
  // Only save once something changes (a first-render save would also wipe a draft when opening an empty page).
  const last = useRef(JSON.stringify([moods, title, body]));

  // W-103: offline, the draft stays in this browser and a banner says so; back online, it saves again.
  const online = useOnline();
  const [lost, setLost] = useState(false);
  const [flash, setFlash] = useState<{ text: string; n: number } | null>(null);
  const offline = lost || !online;
  const localKey = `yn_draft_${rewrite?.id ?? "new"}`;

  // Autosave a moment after typing stops: to the account, and to this browser in case the connection drops.
  useEffect(() => {
    const now = JSON.stringify([moods, title, body]);
    if (now === last.current) return;
    const t = setTimeout(async () => {
      try { localStorage.setItem(localKey, JSON.stringify({ moods, title, body })); } catch { /* private mode */ }
      if (!navigator.onLine) { setLost(true); setSaved("이 기기에 임시 저장됨"); return; }
      try {
        await saveDraft({ mood: moods[0], moods, title, body, source_star_id: rewrite?.id ?? null });
        last.current = now;
        setLost(false);
        setSaved(`임시 저장됨 · ${new Intl.DateTimeFormat("ko-KR", { hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date())}`);
      } catch { setLost(true); setSaved("이 기기에 임시 저장됨"); }
    }, 1200);
    return () => clearTimeout(t);
  }, [moods, title, body, rewrite?.id, localKey, online]);

  const retry = async () => {
    if (!navigator.onLine) { setFlash((f) => ({ text: "연결을 확인해 주세요", n: (f?.n ?? 0) + 1 })); return; }
    try {
      await saveDraft({ mood: moods[0], moods, title, body, source_star_id: rewrite?.id ?? null });
      last.current = JSON.stringify([moods, title, body]);
      setLost(false);
      setSaved("임시 저장됨");
      setFlash((f) => ({ text: "다시 연결됐어요", n: (f?.n ?? 0) + 1 }));
    } catch { setFlash((f) => ({ text: "연결을 확인해 주세요", n: (f?.n ?? 0) + 1 })); }
  };
  // Back online after a drop: save at once, hide the banner and say so.
  const wasOffline = useRef(false);
  useEffect(() => {
    if (!online) { wasOffline.current = true; return; }
    if (!wasOffline.current) return;
    wasOffline.current = false;
    const t = setTimeout(retry, 0);
    return () => clearTimeout(t);
  });
  // W-93: no free reading left and too few coins: say so before the confirm (and when the server says so).
  const short = freeStarToday <= 0 && coins < STAR_COST;
  const openFloat = () => (short ? shortage : confirm).current?.showModal();
  useEffect(() => { if (state?.code === "insufficient_coins") { confirm.current?.close(); shortage.current?.showModal(); } }, [state]);

  // W-92 쓰던 글을 어떻게 할까요?: 닫기 (links marked data-leave) asks once something is written.
  const changed = (title.trim() || body.trim()) && JSON.stringify([title, body]) !== JSON.stringify([start?.title ?? "", start?.body ?? ""]);
  useEffect(() => {
    if (!changed) return;
    const onClick = (e: MouseEvent) => {
      const a = (e.target as Element | null)?.closest?.("a[data-leave]") as HTMLAnchorElement | null;
      if (!a) return;
      e.preventDefault();
      setLeaveTo(a.getAttribute("href") ?? "/");
      leave.current?.showModal();
    };
    document.addEventListener("click", onClick, true);
    return () => document.removeEventListener("click", onClick, true);
  }, [changed]);
  const keepAndGo = async () => {
    try { await saveDraft({ mood: moods[0], moods, title, body, source_star_id: rewrite?.id ?? null }); } catch { /* kept in this browser */ }
    router.push(leaveTo as never);
  };
  const discardAndGo = async () => {
    try { localStorage.removeItem(localKey); } catch { /* private mode */ }
    try { await saveDraft({ mood: moods[0], moods, title: "", body: "", source_star_id: rewrite?.id ?? null }); } catch { /* offline */ }
    last.current = JSON.stringify([moods, "", ""]);
    router.push(leaveTo as never);
  };
  const extraDialogs = (
    <>
      <dialog ref={leave} className="card sheet" aria-labelledby="leave-title">
        <h2 id="leave-title" className="h3">쓰던 글을 어떻게 할까요?</h2>
        <p className="body-s muted">글은 사라지지 않게 임시로 저장해 둘 수 있어요.</p>
        <button type="button" className="btn btn-primary btn-block" onClick={keepAndGo}>임시 저장하고 나가기</button>
        <button type="button" className="btn btn-secondary btn-block" onClick={() => leave.current?.close()}>계속 쓰기</button>
        <button type="button" className="btn btn-danger btn-block" onClick={discardAndGo}>버리기</button>
      </dialog>
      <dialog ref={shortage} className="card sheet" aria-labelledby="short-title">
        <h2 id="short-title" className="h3">코인이 조금 부족해요</h2>
        <p className="body-s muted">오늘 무료 별빛 받기는 이미 썼어요. 별빛을 받으려면 코인 {STAR_COST}개가 필요해요. 지금 코인 {coins}개예요. 별빛 없이 띄우는 건 무료예요.</p>
        <CoinsLink className="btn btn-primary btn-block">코인 충전</CoinsLink>
        <ConfirmKeep label="별빛 없이 띄우기" onDone={() => shortage.current?.close()} />
        <button type="button" className="btn btn-ghost btn-block" onClick={() => shortage.current?.close()}>계속 쓰기</button>
      </dialog>
    </>
  );
  // Floating needs the server; offline it waits instead of failing.
  const guard = (e: React.FormEvent) => { if (!navigator.onLine) { e.preventDefault(); setLost(true); confirm.current?.close(); } };
  const offlineUi = <>{offline && <OfflineBanner onRetry={retry} />}{flash && !offline && <FlashToast key={flash.n} message={flash.text} />}{flash && offline && flash.text !== "다시 연결됐어요" && <FlashToast key={flash.n} message={flash.text} />}</>;

  const length = body.trim().length;
  const canFloat = length >= MIN_FLOAT_LENGTH;
  const freeLeft = freeStarToday > 0;

  const confirmDialog = (
    <>
      {/* Figma W-45 (기획서 17.5): floating with starlight locks the writing, so it asks first. */}
      <dialog ref={confirm} className={`card ${styles.dialog}`} aria-labelledby="float-title">
        {rewrite ? (
          <>
            {/* Figma W-46: a rewrite becomes a new star; the old one and its starlight stay. */}
            <h2 id="float-title" className="h2">고쳐 쓴 글을 새 별로 띄울까요?</h2>
            <p className="body-s muted">「{rewrite.title}」를 고쳐 쓴 글이에요. 원래 별과 별빛은 그대로 남고, 새 별이 하나 더 생겨 원래 별과 이어져요.</p>
            <p className="body-s muted">별빛을 받으면 {freeLeft ? "오늘 무료 1번을 써요" : `${STAR_COST}코인이 들어요 (보유 ${coins})`}. 별빛 없이 띄우면 무료예요.</p>
            {canFloat ? <ConfirmFloat label="별빛 받고 새 별로 띄우기" onDone={() => confirm.current?.close()} />
              : <p className="caption faint">별빛은 {MIN_FLOAT_LENGTH}자부터 받을 수 있어요.</p>}
            <ConfirmKeep label="별빛 없이 새 별로 띄우기" onDone={() => confirm.current?.close()} />
            <button type="button" className="btn btn-ghost" onClick={() => confirm.current?.close()}>조금 더 고칠게요</button>
          </>
        ) : (
        <>
        <h2 id="float-title" className="h2">별빛을 받아 띄울까요?</h2>
        <p className="body-s muted">별빛 프리즘이 글을 읽고 별빛·깊이·고유한 별 모양을 줘요. {freeLeft ? "오늘 무료 1번 남았어요." : `${STAR_COST}코인이 들어요 (보유 ${coins}).`}</p>
        <p className="body-s muted">별빛을 받으면 이 글은 잠겨서 고칠 수 없어요. 고치고 싶으면 &lsquo;고쳐 쓰기&rsquo;로 새 별을 만들 수 있어요.</p>
        <ConfirmFloat label={freeLeft ? "별빛 받고 띄우기 · 오늘 무료 1번" : `별빛 받고 띄우기 · ${STAR_COST}코인`} onDone={() => confirm.current?.close()} />
        <button type="button" className="btn btn-ghost" onClick={() => confirm.current?.close()}>조금 더 쓸게요</button>
        </>
        )}
      </dialog>
    </>
  );

  // Figma W-73: 고쳐 쓰기 is one quiet column; the old star stays, the new one is linked to it.
  if (rewrite) {
    return (
      <form action={action} className={styles.rewrite} onSubmit={guard}>
        <input type="hidden" name="moods" value={moods.join(",")} />
        <input type="hidden" name="rewrite_of" value={rewrite.id} />
        <AttemptField />
        <div className={styles.rewriteTop}>
          <Link href={`/stars/${rewrite.id}`} className={styles.close} data-leave>닫기</Link>
          <span className="label-m">고쳐 쓰기</span>
          <span className={`caption faint ${styles.saved}`}>{saved ?? ""}</span>
        </div>
        <div className={styles.banner}>
          <Info size={18} />
          <span>「{rewrite.title}」를 고쳐 쓰고 있어요. 원래 별과 별빛은 그대로 남고, 띄우면 새 별이 되어 원래 별과 이어져요.</span>
        </div>
        <div className={styles.moods} role="group" aria-label="오늘의 기분">
          {MOODS.map((m) => (
            <button key={m.key} type="button" aria-pressed={moods.includes(m.key)} className={styles.mood}
              style={{ ["--c" as string]: m.color }} onClick={() => toggleMood(m.key)}>{m.label}</button>
          ))}
        </div>
        <input name="title" className={`h2 ${styles.title}`} placeholder="제목 없는 별" value={title} maxLength={60}
          onChange={(e) => setTitle(e.target.value)} aria-label="제목" />
        <textarea name="body" className={`journal ${styles.text} ${styles.rewriteText}`} value={body} maxLength={20000}
          onChange={(e) => setBody(e.target.value)} aria-label="본문" />
        <span className={`caption faint ${styles.count}`}>{length.toLocaleString("ko-KR")}자</span>
        {state?.error && (
          <div className={styles.error} role="alert">
            {state.error}
            {state.code === "insufficient_coins" && <CoinsLink className={styles.link}>코인 충전하기</CoinsLink>}
          </div>
        )}
        <button type="button" className="btn btn-primary btn-block" disabled={length === 0} onClick={() => confirm.current?.showModal()}>새 별로 띄우기</button>
        <PrismOverlay mode="float" />
        {confirmDialog}
        {extraDialogs}
        {offlineUi}
      </form>
    );
  }

  return (
    <form action={action} className={styles.body} onSubmit={guard}>
      <input type="hidden" name="moods" value={moods.join(",")} />
      <AttemptField />
      {source && <input type="hidden" name={rewrite ? "rewrite_of" : "link_to"} value={source.id} />}
      <div className={`card ${styles.editor}`}>
        <div className={styles.moods} role="group" aria-label="오늘의 기분">
          {MOODS.map((m) => (
            <button key={m.key} type="button" aria-pressed={moods.includes(m.key)} className={styles.mood}
              style={{ ["--c" as string]: m.color }} onClick={() => toggleMood(m.key)}>{m.label}</button>
          ))}
        </div>
        <p className="caption faint" style={{ marginTop: -12 }}>오늘의 마음을 여러 개 고를 수 있어요 · 처음 고른 마음이 별의 색이 돼요</p>
        <input name="title" className={`h1 ${styles.title}`} placeholder="제목 없는 별" value={title} maxLength={60}
          onChange={(e) => setTitle(e.target.value)} aria-label="제목" />
        <textarea name="body" className={`journal ${styles.text}`} placeholder="오늘은 어떤 마음이 머물렀나요? 떠오르는 대로 적어 주세요."
          value={body} maxLength={20000} onChange={(e) => setBody(e.target.value)} aria-label="본문" />
        <div className={styles.footer}>
          <span className="caption faint">{length.toLocaleString("ko-KR")}자{!canFloat && length > 0 ? ` · ${MIN_FLOAT_LENGTH - length}자 더 쓰면 별빛을 받을 수 있어요` : ""}</span>
          <span className={styles.spacer} />
          {saved && <span className="caption faint">{saved}</span>}
          {rewrite ? (
            <button type="button" className="btn btn-secondary" disabled={length === 0} onClick={() => confirm.current?.showModal()}>별빛 없이 띄우기</button>
          ) : <Submit mode="keep" label="별빛 없이 띄우기" style="btn-secondary" disabled={length === 0} />}
          <button type="button" className="btn btn-primary" disabled={!canFloat} onClick={openFloat}>별빛 받고 띄우기</button>
        </div>
      </div>
      <aside className={styles.side}>
        {source?.kind === "link" ? (
          <div className={styles.banner}>
            <Info size={18} />
            <span>지난번 기록 · {source.title}{source.question && <><br />{source.question}</>}</span>
          </div>
        ) : (
          <div className={styles.banner}>
            <Info size={18} />
            {freeLeft ? "오늘 무료 별빛 받기가 1번 남았어요." : `오늘 무료 별빛 받기를 썼어요. 별빛을 받으면 ${STAR_COST}코인이 들어요 (보유 ${coins}).`}
          </div>
        )}
        {state?.error && (
          <div className={styles.error} role="alert">
            {state.error}
            {state.code === "insufficient_coins" && <CoinsLink className={styles.link}>코인 충전하기</CoinsLink>}
          </div>
        )}
        <div className={`card ${styles.tips}`}>
          <span className="label-m">쓰는 동안</span>
          <ul>
            <li>떠오르는 대로 적어도 괜찮아요. 맞춤법은 신경 쓰지 않아도 돼요.</li>
            <li>별빛은 {MIN_FLOAT_LENGTH}자부터 받을 수 있어요. 짧은 날은 별빛 없이 띄워도 괜찮아요.</li>
            <li>별빛 받고 띄우면 별빛과 별빛 풀이를 받아요. 별빛을 받은 글은 고칠 수 없어요.</li>
          </ul>
        </div>
        <p className={`caption faint ${styles.privacy}`}><Lock size={16} />글은 나에게만 보여요. 우주 광장에는 내가 고른 한 줄만 나가요.</p>
      </aside>
      <PrismOverlay mode="float" />
      {confirmDialog}
      {extraDialogs}
      {offlineUi}
    </form>
  );
}

// Submits the surrounding form with mode=float (the dialog sits inside the form).
function ConfirmFloat({ label, onDone }: { label: string; onDone: () => void }) {
  const { pending } = useFormStatus();
  return <button name="mode" value="float" className="btn btn-primary btn-block" disabled={pending} onClick={(e) => { freshAttempt(e); setTimeout(onDone, 0); }}>{label}</button>;
}

function ConfirmKeep({ label, onDone }: { label: string; onDone: () => void }) {
  const { pending } = useFormStatus();
  return <button name="mode" value="keep" className="btn btn-secondary btn-block" disabled={pending} onClick={() => setTimeout(onDone, 0)}>{label}</button>;
}

function Submit({ mode, label, style, disabled }: { mode: "keep" | "float"; label: string; style: string; disabled: boolean }) {
  const { pending } = useFormStatus();
  return <button name="mode" value={mode} className={`btn ${style}`} disabled={disabled || pending}>{label}</button>;
}
