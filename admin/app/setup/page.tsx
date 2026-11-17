import type { Metadata } from "next";
import { SetupForm } from "./SetupForm";
import "../login/login.css";

export const metadata: Metadata = { title: "운영자 설정" };

// The invitation link from A-14: set a password and two-step sign-in, then sign in (Figma A2-18).
export default async function SetupPage({ searchParams }: PageProps<"/setup">) {
  const sp = await searchParams;
  const token = typeof sp.token === "string" && /^[\w-]{16,200}$/.test(sp.token) ? sp.token : null;
  return (
    <main className="login">
      <div className="login-card">
        <div className="brand"><b>YOUNIYA</b><span className="faint">운영자 콘솔</span></div>
        {token ? <SetupForm token={token} /> : (
          <>
            <h1>운영자 계정 설정</h1>
            <p className="error">초대 링크가 올바르지 않아요. 초대한 운영자에게 새 링크를 받아 주세요.</p>
          </>
        )}
      </div>
    </main>
  );
}
