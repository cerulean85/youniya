import type { Metadata } from "next";
import { Info } from "@/components/icons";
import { SITE_URL } from "@/lib/config";
import { agree } from "./actions";
import { ConsentForm } from "./ConsentForm";
import styles from "../login/login.module.css";

export const metadata: Metadata = { title: "가입 동의" };

// Figma W-21.
export default function WelcomePage() {
  return (
    <div className={styles.page}>
      <section className={styles.pane} style={{ width: "100%" }}>
        <div className={`card ${styles.card}`} style={{ alignItems: "stretch", textAlign: "left" }}>
          <h1 className="h1">시작하기 전에<br />함께 약속할게요</h1>
          <p className={`body-s ${styles.notice}`}><Info size={18} />쓴 글은 AI 학습에 쓰이지 않아요. 언제든 모두 삭제할 수 있고, YOUNIYA는 상담이나 진단을 대신하지 않아요.</p>
          <ConsentForm action={agree} site={SITE_URL} />
        </div>
      </section>
    </div>
  );
}
