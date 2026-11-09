import Link from "next/link";

export default function Forbidden() {
  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center" }}>
      <div className="card" style={{ padding: 32, display: "flex", flexDirection: "column", gap: 12, width: 400 }}>
        <h1 style={{ fontSize: 20 }}>이 화면을 볼 권한이 없어요</h1>
        <p className="muted">신고 담당 운영자는 신고 처리, 별지기, 문의만 볼 수 있어요.</p>
        <Link href="/reports" className="btn">신고 처리로 가기</Link>
      </div>
    </main>
  );
}
