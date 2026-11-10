import type { Metadata } from "next";
import { Suspense } from "react";
import { NicknameForm } from "@/components/NicknameForm";
import { api } from "@/lib/api";
import { longDate } from "@/lib/format";
import type { Me } from "@/lib/types";
import { Back } from "../Back";
import styles from "../settings.module.css";

export const metadata: Metadata = { title: "별지기 이름" };

// Figma W-80: once every 30 days; the new name follows every star and line already shared.
export default function NicknamePage() {
  return (
    <div className={styles.page}>
      <Back />
      <Suspense fallback={<div className={styles.loading} aria-busy="true" />}><Nickname /></Suspense>
    </div>
  );
}

async function Nickname() {
  const me = await api<Me>("/v1/me");
  const rename = Boolean(me.nickname_rename_required);
  const wait = !rename && me.nickname_next_change && new Date(me.nickname_next_change) > new Date() ? me.nickname_next_change : null;
  return (
    <>
      <h1 className="h1">{me.nickname ? "별지기 이름 바꾸기" : "별지기 이름 정하기"}</h1>
      <p className="body-s muted">바꾸면 지금까지 나눈 별과 남긴 별빛 한 줄 모두에도 새 이름이 보여요.</p>
      {rename && <p className={styles.notice}>운영자 요청이 있어요. 새 이름으로 바꾸면 바로 다시 나눌 수 있어요(30일 제한 없이).</p>}
      {wait ? (
        <>
          <p className={styles.current}><span className="caption faint">별지기 이름</span><span className="body-l">{me.nickname}</span></p>
          <p className={styles.next}>다음 변경은 {longDate(wait)}부터 할 수 있어요</p>
        </>
      ) : <NicknameForm initial={me.nickname ?? ""} next="/settings" submit={me.nickname ? "바꾸기" : "정하기"} />}
    </>
  );
}
