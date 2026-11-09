import Link from "next/link";

// Inside the app (a star or a page that isn't there, or isn't yours).
export default function NotFound() {
  return (
    <div className="card" style={{ alignSelf: "center", marginTop: 80, maxWidth: 440, padding: 32, borderRadius: 24, display: "flex", flexDirection: "column", gap: 12, textAlign: "center" }}>
      <h1 className="h2">찾는 별이 없어요</h1>
      <p className="body-m muted">지워졌거나, 주소가 바뀌었거나, 다른 별지기의 별이에요.</p>
      <Link href="/" className="btn btn-primary">나의 밤하늘로</Link>
    </div>
  );
}
