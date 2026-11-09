import Link from "next/link";

export default function NotFound() {
  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center", padding: 24 }}>
      <div className="card" style={{ maxWidth: 440, padding: 32, borderRadius: 24, display: "flex", flexDirection: "column", gap: 12, textAlign: "center" }}>
        <h1 className="h2">찾는 페이지가 없어요</h1>
        <p className="body-m muted">주소가 바뀌었거나 없는 페이지예요.</p>
        <Link href="/" className="btn btn-primary">YOUNIYA로</Link>
      </div>
    </main>
  );
}
