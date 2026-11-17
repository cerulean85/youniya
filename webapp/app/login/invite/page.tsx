import type { Metadata } from "next";
import styles from "../login.module.css";
import { InviteForm } from "./InviteForm";

export const metadata: Metadata = { title: "초대 계정으로 로그인" };

// Mobile 02-1 on the web: the same pane as W-20, the form in place of the sign-in buttons.
export default function InviteLoginPage() {
  return (
    <div className={styles.page}>
      <section className={styles.pane}>
        <div className={`card ${styles.card}`}>
          <h2 className="h2">초대 계정으로 로그인</h2>
          <p className="body-m muted">운영팀이 드린 계정으로만 들어올 수 있어요. 처음이라면 Apple이나 Google로 시작해 주세요.</p>
          <InviteForm />
        </div>
      </section>
    </div>
  );
}
