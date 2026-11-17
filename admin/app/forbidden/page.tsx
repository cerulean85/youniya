import Link from "next/link";
import "../login/login.css";

// Figma A2-19: a moderator on an owner screen.
export default function Forbidden() {
  return (
    <main className="login">
      <div className="login-card">
        <div className="brand"><b>YOUNIYA</b><span className="faint">운영자 콘솔</span></div>
        <h1>이 화면을 볼 권한이 없어요</h1>
        <p className="muted">신고 담당 운영자는 신고 처리, 별지기, 문의만 볼 수 있어요.</p>
        <Link href="/reports" className="btn btn-outline" style={{ alignSelf: "flex-start" }}>신고 처리로 가기</Link>
      </div>
    </main>
  );
}
