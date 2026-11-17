"use client";

import { useEffect, useState } from "react";

export function RetryAfter({ seconds, back }: { seconds: number; back: string }) {
  const [left, setLeft] = useState(seconds);
  useEffect(() => {
    if (left <= 0) return;
    const t = setTimeout(() => setLeft((n) => n - 1), 1000);
    return () => clearTimeout(t);
  }, [left]);
  const label = left <= 0 ? "다시 시도하기" : left >= 60 ? `${Math.ceil(left / 60)}분 뒤에 다시 시도` : `${left}초 뒤에 다시 시도`;
  // Figma 웹 v1.1 · 오류 · 요청 몰림 (644:31823): the timed retry, a way back to the writing now, and what the timer does.
  return (
    <>
      <a href={back} className="btn btn-primary" aria-disabled={left > 0} onClick={(e) => { if (left > 0) e.preventDefault(); }}>{label}</a>
      <a href={back} className="btn btn-ghost">{back === "/" ? "쓰던 글로 돌아가기" : "하던 화면으로 돌아가기"}</a>
      <p className="caption muted">{left > 0 ? "0초가 되면 버튼이 켜지고, 누르면 하던 화면으로 돌아가요." : "이제 다시 시도할 수 있어요."}</p>
    </>
  );
}
