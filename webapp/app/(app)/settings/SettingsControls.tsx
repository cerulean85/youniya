"use client";

import { useOptimistic, useRef, useTransition } from "react";
import { useFormStatus } from "react-dom";
import { ChevronRight } from "@/components/icons";
import { NicknameForm } from "@/components/NicknameForm";
import { deleteAccount, setMarketing, unblock, unshareAll } from "./actions";
import styles from "./settings.module.css";

// 15.1: once every 30 days; the change follows every star and line already shared.
export function NicknameRow({ nickname, nextChange }: { nickname: string | null; nextChange: string | null }) {
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" className={styles.row} onClick={() => dialog.current?.showModal()} disabled={Boolean(nextChange)}>
        <span>별지기 이름</span>
        <span className={styles.value}>{nickname ?? "정하지 않았어요"}{nextChange ? ` · ${nextChange}부터 바꿀 수 있어요` : <ChevronRight size={16} />}</span>
      </button>
      <dialog ref={dialog} className={`card ${styles.dialog}`} aria-labelledby="nick-title">
        <h2 id="nick-title" className="h2">{nickname ? "별지기 이름 바꾸기" : "별지기 이름 정하기"}</h2>
        <p className="body-s muted">바꾸면 지금까지 나눈 별과 건넨 별빛 한 줄이 모두 새 이름으로 보여요. 30일에 한 번 바꿀 수 있어요.</p>
        <NicknameForm initial={nickname ?? ""} next="/settings" submit={nickname ? "이 이름으로 바꾸기" : "이 이름으로 정하기"} />
        <button type="button" className="btn btn-ghost" onClick={() => dialog.current?.close()}>취소</button>
      </dialog>
    </>
  );
}

export function MarketingToggle({ on }: { on: boolean }) {
  const [value, setValue] = useOptimistic(on);
  const [, start] = useTransition();
  return (
    <label className={styles.row}>
      <span>새 기능·혜택 알림</span>
      <input type="checkbox" role="switch" className={styles.switch} checked={value}
        onChange={(e) => { const next = e.target.checked; start(async () => { setValue(next); await setMarketing(next); }); }} />
    </label>
  );
}

// 설정 › 차단한 별지기: when and where, never who.
export function Blocks({ blocks }: { blocks: { id: string; when: string; where: string }[] }) {
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" className={styles.row} onClick={() => dialog.current?.showModal()}>
        <span>차단한 별지기</span><span className={styles.value}>{blocks.length}명<ChevronRight size={16} /></span>
      </button>
      <dialog ref={dialog} className={`card ${styles.dialog}`} aria-labelledby="blocks-title">
        <h2 id="blocks-title" className="h2">차단한 별지기</h2>
        <p className="body-s muted">누구인지는 보이지 않아요. 풀면 서로의 별과 별빛 한 줄이 다시 보여요.</p>
        {blocks.length === 0 ? <p className="body-s faint">차단한 별지기가 없어요.</p> : (
          <ul className={styles.blocks}>
            {blocks.map((b) => (
              <li key={b.id}>
                <span className="body-s">{b.when} · {b.where}</span>
                <form action={unblock.bind(null, b.id)}><Pending label="차단 풀기" busy="푸는 중…" style="btn-ghost" /></form>
              </li>
            ))}
          </ul>
        )}
        <button type="button" className="btn btn-secondary" onClick={() => dialog.current?.close()}>닫기</button>
      </dialog>
    </>
  );
}

export function DangerZone({ shared }: { shared: number }) {
  const unshare = useRef<HTMLDialogElement>(null);
  const remove = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" className={styles.row} onClick={() => unshare.current?.showModal()} disabled={shared === 0}>
        <span>모든 공유 거두기</span><ChevronRight size={16} />
      </button>
      <button type="button" className={`${styles.row} ${styles.danger}`} onClick={() => remove.current?.showModal()}>
        <span>계정 영구 삭제</span><ChevronRight size={16} />
      </button>
      <dialog ref={unshare} className={`card ${styles.dialog}`} aria-labelledby="unshare-title">
        <form action={async () => { await unshareAll(); unshare.current?.close(); }}>
          <h2 id="unshare-title" className="h2">나눈 별을 모두 거둘까요?</h2>
          <p className="body-s muted">우주 광장에 나눈 별 {shared}개가 모두 내려가요. 이미 받은 공명과 별빛 한 줄은 그대로 남아요.</p>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => unshare.current?.close()}>취소</button>
            <Pending label="모두 거두기" busy="거두는 중…" style="btn-primary" />
          </div>
        </form>
      </dialog>
      <dialog ref={remove} className={`card ${styles.dialog}`} aria-labelledby="delete-title">
        <form action={deleteAccount}>
          <h2 id="delete-title" className="h2">계정을 영구 삭제할까요?</h2>
          <p className="body-s muted">모든 별과 별빛, 별자리, 나눈 별과 받은 별빛 한 줄, 남은 코인이 사라지고 되살릴 수 없어요. 결제 기록만 법에 따라 5년 동안 보관해요.</p>
          <label className={styles.confirm}>
            <span className="caption muted">확인을 위해 &lsquo;삭제&rsquo;라고 적어 주세요</span>
            <input name="confirm" autoComplete="off" required pattern="삭제" />
          </label>
          <div className={styles.dialogActions}>
            <button type="button" className="btn btn-ghost" onClick={() => remove.current?.close()}>취소</button>
            <Pending label="영구 삭제" busy="삭제하는 중…" style={styles.dangerButton} />
          </div>
        </form>
      </dialog>
    </>
  );
}

function Pending({ label, busy, style }: { label: string; busy: string; style: string }) {
  const { pending } = useFormStatus();
  return <button className={`btn ${style}`} disabled={pending}>{pending ? busy : label}</button>;
}
