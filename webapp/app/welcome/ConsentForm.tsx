"use client";

import { useState } from "react";
import { ChevronRight } from "@/components/icons";
import styles from "./consent.module.css";

const ITEMS = [
  { name: "terms", label: "(필수) 이용약관", href: "/terms", required: true },
  { name: "privacy", label: "(필수) 개인정보 처리방침", href: "/privacy", required: true },
  { name: "sensitive", label: "(필수) 심리 일기 수집·이용 (민감정보)", href: "/sensitive", required: true },
  { name: "marketing", label: "(선택) 새 기능·혜택 알림", href: null, required: false },
];

export function ConsentForm({ action, site }: { action: (f: FormData) => Promise<void>; site: string }) {
  const [on, setOn] = useState<Record<string, boolean>>({});
  const all = ITEMS.every((i) => on[i.name]);
  const ready = ITEMS.filter((i) => i.required).every((i) => on[i.name]);
  return (
    <form action={action} className={styles.form}>
      <label className={`${styles.row} ${styles.all}`}>
        <input type="checkbox" checked={all} onChange={(e) => setOn(Object.fromEntries(ITEMS.map((i) => [i.name, e.target.checked])))} />
        <span className="label-m">전체 동의</span>
      </label>
      {ITEMS.map((i) => (
        <label key={i.name} className={styles.row}>
          <input type="checkbox" name={i.name} checked={!!on[i.name]} onChange={(e) => setOn({ ...on, [i.name]: e.target.checked })} />
          <span className="body-m">{i.label}</span>
          {i.href && <a href={`${site}${i.href}`} target="_blank" rel="noreferrer" aria-label={`${i.label} 보기`} className={styles.view}><ChevronRight size={16} /></a>}
        </label>
      ))}
      <button className="btn btn-primary btn-block" disabled={!ready}>동의하고 시작하기</button>
    </form>
  );
}
