import { notFound } from "next/navigation";
import { NAV } from "@/lib/nav";
import { requireOperator } from "@/lib/session";

// The screens not built yet (A-02, A-05~A-12, A-14): named, with their Figma frame, behind the same roles.
export default async function Section({ params }: PageProps<"/[section]">) {
  const { section } = await params;
  const item = NAV.find((n) => n.href === `/${section}` && !n.ready);
  if (!item) notFound();
  await requireOperator(item.roles);
  return (
    <>
      <div className="head"><div><h1>{item.label}</h1></div></div>
      <div className="card placeholder">
        <h2>준비 중이에요</h2>
        <p className="muted">Figma Admin {item.figma} 화면이에요. 서버의 운영자 API(7단계)가 나오면 붙여요.</p>
      </div>
    </>
  );
}
