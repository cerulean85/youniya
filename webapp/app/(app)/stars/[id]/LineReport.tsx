"use client";

import { useRef } from "react";
import { useFormStatus } from "react-dom";
import { reportLine } from "./actions";

const REASONS = [["hurtful", "상처를 주는 말이에요"], ["personal_info", "개인정보가 드러나 있어요"], ["spam", "광고나 스팸이에요"], ["other", "그 밖의 이유가 있어요"]] as const;

// Figma W-96 (Mobile 12-4 / 100): a reason, and whether to block its writer too.
export function LineReport({ id, lineId }: { id: string; lineId: string }) {
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" onClick={() => dialog.current?.showModal()}>신고</button>
      <dialog ref={dialog} className="card sheet" aria-labelledby={`report-${lineId}`}>
        <form action={async (f) => { await reportLine(id, lineId, f); dialog.current?.close(); }}>
          <h2 id={`report-${lineId}`} className="h3">이 별빛을 신고할까요?</h2>
          <p className="body-s muted">신고한 별빛은 바로 가려지고 운영팀이 살펴봐요. 누가 신고했는지는 알리지 않아요.</p>
          <fieldset style={{ border: 0, padding: 0, margin: 0, display: "grid", gap: 10 }}>
            <legend className="sr-only">이유</legend>
            {REASONS.map(([key, label], i) => (
              <label key={key} className="body-s" style={{ display: "flex", gap: 10, alignItems: "center" }}><input type="radio" name="reason" value={key} defaultChecked={i === 0} />{label}</label>
            ))}
          </fieldset>
          <label className="body-s" style={{ display: "flex", gap: 10, alignItems: "center", marginTop: 8 }}><input type="checkbox" name="block" />이 별지기도 차단하기</label>
          <Send />
          <button type="button" className="btn btn-secondary btn-block" onClick={() => dialog.current?.close()}>취소</button>
        </form>
      </dialog>
    </>
  );
}

function Send() {
  const { pending } = useFormStatus();
  return <button className="btn btn-primary btn-block" disabled={pending}>{pending ? "보내는 중…" : "신고하기"}</button>;
}
