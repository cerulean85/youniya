import Link from "next/link";
import { Star } from "@/components/icons";
import { StatusScreen } from "@/components/Status";

// Inside the app (a star or a page that isn't there, or isn't yours); Mobile 별을 찾을 수 없어요.
export default function NotFound() {
  return (
    <StatusScreen icon={<Star size={22} />} title="별을 찾을 수 없어요" body="이미 지웠거나, 주소가 바뀌었거나, 다른 별지기의 별이에요.">
      <Link href="/" className="btn btn-primary btn-block">밤하늘로 돌아가기</Link>
    </StatusScreen>
  );
}
