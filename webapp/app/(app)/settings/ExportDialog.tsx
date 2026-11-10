"use client";

import { useRef, useState } from "react";
import { ChevronRight, Upload } from "@/components/icons";
import { Toast } from "@/components/Flash";
import styles from "./settings.module.css";

type Phase = { kind: "choose" } | { kind: "working"; format: "text" | "pdf"; pct: number };

// Figma W-100 (어떤 형식으로) and W-101 (내보내는 중): the file is gathered in the background, so closing the
// dialog doesn't stop it; it saves itself when done and says so.
export function ExportDialog({ stars }: { stars: number }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [phase, setPhase] = useState<Phase>({ kind: "choose" });
  const [toast, setToast] = useState<{ text: string; n: number } | null>(null);
  const say = (text: string) => setToast((t) => ({ text, n: (t?.n ?? 0) + 1 }));

  const run = async (format: "text" | "pdf") => {
    setPhase({ kind: "working", format, pct: 3 });
    try {
      const res = await fetch(`/settings/export${format === "pdf" ? "?format=pdf" : ""}`, { cache: "no-store" });
      if (!res.ok || !res.body) throw new Error("export");
      const total = Number(res.headers.get("Content-Length")) || 0;
      const reader = res.body.getReader();
      const parts: BlobPart[] = [];
      let got = 0;
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        parts.push(value);
        got += value.length;
        // Without a length, creep towards 90% so it still moves.
        setPhase((p) => p.kind === "working" ? { ...p, pct: total ? Math.min(99, Math.round((got / total) * 100)) : Math.min(90, p.pct + 4) } : p);
      }
      const url = URL.createObjectURL(new Blob(parts, { type: format === "pdf" ? "application/pdf" : "text/plain;charset=utf-8" }));
      Object.assign(document.createElement("a"), { href: url, download: `YOUNIYA 기록.${format === "pdf" ? "pdf" : "txt"}` }).click();
      URL.revokeObjectURL(url);
      say("파일로 내보냈어요");
    } catch {
      say("내보내지 못했어요. 다시 시도해 주세요");
    }
    dialog.current?.close();
    setPhase({ kind: "choose" });
  };

  return (
    <>
      <button type="button" className={styles.row} onClick={() => dialog.current?.showModal()}>
        <Upload size={18} /><span>데이터 내보내기</span><span className={styles.value}><ChevronRight size={16} /></span>
      </button>
      <dialog ref={dialog} className="card sheet" aria-labelledby="export-title">
        {phase.kind === "choose" ? (
          <>
            <h2 id="export-title" className="h3">어떤 형식으로 내보낼까요?</h2>
            <p className="body-s muted">쓴 별과 별자리 이야기를 모두 파일로 내보내요. 파일은 내 기기에만 저장돼요.</p>
            <button type="button" className="btn btn-primary btn-block" onClick={() => run("text")}>텍스트 파일로</button>
            <button type="button" className="btn btn-secondary btn-block" onClick={() => run("pdf")}>PDF로</button>
            <button type="button" className="btn btn-ghost btn-block" onClick={() => dialog.current?.close()}>닫기</button>
          </>
        ) : (
          <>
            <h2 id="export-title" className="h3">내보내는 중이에요</h2>
            <p className="body-s muted">별 {stars}개와 별자리 이야기를 {phase.format === "pdf" ? "PDF" : "텍스트"} 파일로 모으고 있어요. 창을 닫아도 이어서 만들어요.</p>
            <div className={styles.progress} role="progressbar" aria-valuenow={phase.pct} aria-valuemin={0} aria-valuemax={100}><i style={{ width: `${phase.pct}%` }} /></div>
            <p className="caption faint">{phase.pct}% · {phase.pct >= 70 ? "거의 다 됐어요" : "모으는 중이에요"}</p>
            <button type="button" className="btn btn-ghost btn-block" onClick={() => dialog.current?.close()}>닫기</button>
          </>
        )}
      </dialog>
      {toast && <Toast key={toast.n} title={toast.text} />}
    </>
  );
}
