"use client";

import { useEffect, useRef, useState } from "react";
import { drawConstellationCard, drawStarCard, type ConstellationCardData, type StarCardData } from "@/lib/card-image";
import { FlashToast } from "./Offline";
import styles from "./ShareCard.module.css";

type Props =
  | { kind: "star"; data: StarCardData; title: string; label?: string; className?: string }
  | { kind: "constellation"; data: ConstellationCardData; label?: string; className?: string };

// 기획서 22장 (Mobile 12-12·12-13) and 23장 (08-9) as a web modal: a preview, 별 제목 넣기 for a star (off at first),
// 이미지로 저장 (PNG 1080×1920) and 다른 앱으로 공유 where the browser can share files. Made here, never uploaded.
export function ShareCard(props: Props) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [open, setOpen] = useState(false);
  const [withTitle, setWithTitle] = useState(false);
  const [card, setCard] = useState<{ blob: Blob; url: string } | null>(null);
  const [canShare, setCanShare] = useState(false);
  const [toast, setToast] = useState<{ text: string; n: number } | null>(null);
  const say = (text: string) => setToast((t) => ({ text, n: (t?.n ?? 0) + 1 }));
  const star = props.kind === "star";
  const name = star ? props.title : `${props.data.name}자리`;

  useEffect(() => {
    if (!open) return;
    let gone = false, made: string | null = null;
    const draw = props.kind === "star" ? drawStarCard({ ...props.data, title: withTitle ? props.title : null }) : drawConstellationCard(props.data);
    draw.then((blob) => {
      if (gone || !blob) return;
      made = URL.createObjectURL(blob);
      setCard({ blob, url: made });
      const file = new File([blob], "youniya.png", { type: "image/png" });
      setCanShare(typeof navigator.canShare === "function" && navigator.canShare({ files: [file] }));
    }).catch(() => { if (!gone) say("카드를 만들지 못했어요"); });
    return () => { gone = true; if (made) URL.revokeObjectURL(made); };
    // The card depends only on what it shows.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, withTitle]);

  const file = () => `${name.replace(/[\\/:*?"<>|]/g, "").trim() || "YOUNIYA"} 카드.png`;
  const save = () => {
    if (!card) return;
    Object.assign(document.createElement("a"), { href: card.url, download: file() }).click();
    say("이미지로 저장했어요");
  };
  const share = async () => {
    if (!card) return;
    try { await navigator.share({ files: [new File([card.blob], file(), { type: "image/png" })] }); }
    catch (e) { if ((e as Error)?.name !== "AbortError") say("공유하지 못했어요"); }
  };
  const close = () => { dialog.current?.close(); };

  return (
    <>
      <button type="button" className={props.className ?? "btn btn-ghost"} onClick={() => { setOpen(true); dialog.current?.showModal(); }}>
        {props.label ?? "카드 공유"}
      </button>
      <dialog ref={dialog} className={`card sheet ${styles.dialog}`} aria-labelledby="card-title" onClose={() => { setOpen(false); setCard(null); }}>
        <h2 id="card-title" className="h3">{star ? "별 카드로 나누기" : "별자리 카드로 나누기"}</h2>
        <p className="body-s muted">{star ? "글은 담기지 않아요. 별 모양·별빛·날짜·마음만 담겨요." : "글은 담기지 않아요. 그달 별자리와 채운 자리만 담겨요."}</p>
        <div className={styles.preview}>
          {/* eslint-disable-next-line @next/next/no-img-element -- a blob made in the browser */}
          {card ? <img src={card.url} alt={`${name} 카드 미리 보기`} /> : <span className="caption faint">카드를 그리는 중…</span>}
        </div>
        {star && (
          <label className={styles.toggle}>
            <span className="label-m">별 제목 넣기</span>
            <input type="checkbox" role="switch" checked={withTitle} onChange={(e) => setWithTitle(e.target.checked)} />
          </label>
        )}
        <button type="button" className="btn btn-primary btn-block" disabled={!card} onClick={save}>이미지로 저장</button>
        {canShare && <button type="button" className="btn btn-secondary btn-block" disabled={!card} onClick={share}>다른 앱으로 공유</button>}
        <button type="button" className="btn btn-ghost btn-block" onClick={close}>닫기</button>
      </dialog>
      {toast && <FlashToast key={toast.n} message={toast.text} />}
    </>
  );
}
