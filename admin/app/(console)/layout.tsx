import { NavLinks, type NavCounts } from "@/components/NavLinks";
import { isMock, listInquiries, listReports } from "@/lib/api";
import { ready } from "@/lib/config";
import { NAV } from "@/lib/nav";
import { requireOperator } from "@/lib/session";
import { signOut } from "../login/actions";
import "./console.css";

// Figma Admin v2/Sidebar (232px) and the page beside it.
export default async function ConsoleLayout({ children }: { children: React.ReactNode }) {
  const { operator } = await requireOperator();
  const items = NAV.filter((n) => n.roles.includes(operator.role));
  // Waiting counts beside 신고 처리 and 문의, only when those parts answer; a failure just leaves them off.
  const [reports, inquiries] = await Promise.all([
    ready("reports") ? listReports("pending").catch(() => null) : null,
    ready("inquiries") ? listInquiries("new").catch(() => null) : null,
  ]);
  const counts: NavCounts = {};
  if (reports) counts["/reports"] = { n: reports.counts?.pending ?? reports.items.length, hot: true };
  if (inquiries) counts["/inquiries"] = { n: inquiries.counts?.new ?? inquiries.items.length };
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand"><b>YOUNIYA</b><span className="faint">운영자 콘솔{isMock ? " · 목 데이터" : ""}</span></div>
        <NavLinks items={items} counts={counts} />
        <div className="me">
          <b>{operator.role === "owner" ? "운영자" : "신고 담당"} · {operator.email.split("@")[0]}</b>
          <span className="faint">{operator.role === "owner" ? "전체 권한" : "신고·별지기·문의"} · 2단계 인증 켜짐</span>
          <form action={signOut}><button className="link">로그아웃</button></form>
        </div>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
