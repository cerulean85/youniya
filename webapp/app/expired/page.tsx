import type { Metadata } from "next";
import { Suspense } from "react";
import { User } from "@/components/icons";
import { StatusScreen } from "@/components/Status";

export const metadata: Metadata = { title: "다시 로그인해 주세요" };

// Figma W-87 (Mobile 39): the session ran out; the sign-in comes back to where it was.
export default function ExpiredPage({ searchParams }: PageProps<"/expired">) {
  return (
    <main style={{ display: "flex", minHeight: "100vh" }}>
      <StatusScreen full icon={<User size={22} />} title="다시 로그인해 주세요" body="쓴 글은 그대로 남아 있어요.">
        <Suspense fallback={<a href="/login" className="btn btn-primary btn-block">로그인</a>}><Again searchParams={searchParams} /></Suspense>
      </StatusScreen>
    </main>
  );
}

async function Again({ searchParams }: Pick<PageProps<"/expired">, "searchParams">) {
  const sp = await searchParams;
  const next = typeof sp.next === "string" && sp.next.startsWith("/") && !sp.next.startsWith("//") ? sp.next : null;
  return <a href={next ? `/login?next=${encodeURIComponent(next)}` : "/login"} className="btn btn-primary btn-block">로그인</a>;
}
