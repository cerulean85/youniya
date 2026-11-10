import type { Metadata } from "next";
import Link from "next/link";
import { Moon } from "@/components/icons";
import { StatusScreen } from "@/components/Status";

export const metadata: Metadata = { title: "계정을 삭제했어요" };

// Figma W-83 (Mobile 113): signed out already, so no sidebar.
export default function DeletedPage() {
  return (
    <main style={{ display: "flex", minHeight: "100vh" }}>
      <StatusScreen full icon={<Moon size={22} />} title="계정을 삭제했어요" body={"그동안 띄운 별과 별자리가 모두 사라졌어요.\n언제든 다시 첫 별을 띄울 수 있어요."}>
        <Link href="/login" className="btn btn-primary btn-block">처음 화면으로</Link>
      </StatusScreen>
    </main>
  );
}
