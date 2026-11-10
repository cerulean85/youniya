"use client";

import Link from "next/link";
import { useEffect, useRef } from "react";
import { Lock, Shield, Sparkle } from "./icons";

const POINTS = [
  { icon: <Sparkle size={18} />, title: "쓴 마음은 단 하나뿐인 별이 돼요", body: "같은 모양의 별은 하나도 없어요." },
  { icon: <Lock size={18} />, title: "나누는 건 내가 고른 별뿐이에요", body: "우주 광장에는 내가 나누기로 고른 별만 별지기 이름과 함께 올라가요." },
  { icon: <Shield size={18} />, title: "쓴 글은 AI 학습에 쓰이지 않아요", body: "언제든 모두 지울 수 있어요. 상담이나 진단을 대신하지 않아요." },
];

// Figma W-91 (Mobile 03-1): once per account in this browser, over the first, empty night sky.
export function WelcomeSheet({ account }: { account: string }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const key = `yn_welcomed_${account}`;
  useEffect(() => {
    try { if (localStorage.getItem(key)) return; localStorage.setItem(key, "1"); } catch { return; }
    dialog.current?.showModal();
  }, [key]);
  return (
    <dialog ref={dialog} className="card sheet" aria-labelledby="welcome-title">
      <h2 id="welcome-title" className="h3">YOUNIYA에 오신 걸 환영해요</h2>
      <p className="body-s muted">시작하기 전에 세 가지만 알려 드릴게요.</p>
      <ul style={{ listStyle: "none", margin: "4px 0 8px", padding: 0, display: "grid", gap: 14 }}>
        {POINTS.map((p) => (
          <li key={p.title} style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
            <span style={{ color: "var(--primary-text)", marginTop: 2 }}>{p.icon}</span>
            <span style={{ display: "grid", gap: 2 }}><b className="label-m">{p.title}</b><span className="caption muted">{p.body}</span></span>
          </li>
        ))}
      </ul>
      <Link href="/write" className="btn btn-primary btn-block" onClick={() => dialog.current?.close()}>첫 별 만들기</Link>
      <button type="button" className="btn btn-ghost btn-block" onClick={() => dialog.current?.close()}>먼저 둘러볼게요</button>
    </dialog>
  );
}
