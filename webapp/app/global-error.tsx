"use client";

import "./globals.css";

// The root layout itself failed: its own document, in the app's dark sky.
export default function GlobalError({ retry }: { error: unknown; retry: () => void }) {
  return (
    <html lang="ko">
      <body>
        <title>YOUNIYA</title>
        <div className="sky" aria-hidden="true" />
        <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24 }}>
          <div className="card" style={{ maxWidth: 400, padding: 32, borderRadius: 24, display: "flex", flexDirection: "column", gap: 12, textAlign: "center" }}>
            <h1 className="h2">화면을 불러오지 못했어요</h1>
            <p className="body-s muted">잠시 뒤에 다시 시도해 주세요. 쓴 별과 코인은 그대로 있어요.</p>
            <button type="button" className="btn btn-primary btn-block" onClick={() => retry()}>다시 시도</button>
          </div>
        </main>
      </body>
    </html>
  );
}
