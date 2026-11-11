import { LogoMark } from "@/components/LogoMark";
import { NavLinks } from "@/components/NavLinks";
import { isMock } from "@/lib/api";
import { NAV } from "@/lib/nav";
import { requireOperator } from "@/lib/session";
import { signOut } from "../login/actions";
import "./console.css";

// Figma Admin Sidebar (240px) and the page beside it.
export default async function ConsoleLayout({ children }: { children: React.ReactNode }) {
  const { operator } = await requireOperator();
  const items = NAV.filter((n) => n.roles.includes(operator.role));
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand"><b><LogoMark size={18} />YOUNIYA</b><span className="faint">운영자 콘솔{isMock ? " · 목 데이터" : ""}</span></div>
        <NavLinks items={items} />
        <div className="me card">
          <b>{operator.role === "owner" ? "운영자" : "신고 담당"} · {operator.email.split("@")[0]}</b>
          <span className="faint">권한: {operator.role === "owner" ? "전체" : "신고·별지기·문의"} · 2단계 인증 켜짐</span>
          <form action={signOut}><button className="link">로그아웃</button></form>
        </div>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
