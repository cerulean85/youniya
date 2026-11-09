import type { Metadata } from "next";
import { isMock } from "@/lib/api";
import { LoginForm } from "./LoginForm";
import "./login.css";

export const metadata: Metadata = { title: "로그인" };

// Figma A-01 운영자 로그인.
export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const sp = await searchParams;
  return (
    <main className="login">
      <div className="card login-card">
        <h1>YOUNIYA 운영자 콘솔</h1>
        {sp.expired && <p className="notice">로그인이 끝났어요. 다시 로그인해 주세요.</p>}
        {isMock && <p className="notice">목 데이터로 실행 중이에요. 로그인 값은 admin/README.md에 있어요.</p>}
        <LoginForm />
      </div>
    </main>
  );
}
