"use client";

import Link from "next/link";
import { useEffect } from "react";
import { Warn, WifiOff } from "@/components/icons";
import { useOnline } from "@/components/Offline";
import { StatusScreen } from "@/components/Status";

// A page that couldn't load (Mobile 35 연결이 잠시 끊겼어요 when offline). Writing in progress is kept by the editor's local draft.
export default function AppError({ error, retry }: { error: unknown; retry: () => void }) {
  const online = useOnline();
  useEffect(() => { console.error(error); }, [error]);
  // Coming back online tries again by itself.
  useEffect(() => { if (online) return; const back = () => retry(); window.addEventListener("online", back); return () => window.removeEventListener("online", back); }, [online, retry]);
  return online ? (
    <StatusScreen icon={<Warn size={22} />} title="화면을 불러오지 못했어요" body="잠시 뒤에 다시 시도해 주세요. 쓴 별과 코인은 그대로 있어요.">
      <button type="button" className="btn btn-primary btn-block" onClick={() => retry()}>다시 시도</button>
      <Link href="/" className="btn btn-secondary btn-block">나의 밤하늘로</Link>
    </StatusScreen>
  ) : (
    <StatusScreen icon={<WifiOff size={22} />} title="연결이 잠시 끊겼어요" body="쓰던 글은 이 기기에 안전하게 있어요. 연결되면 다시 불러와요.">
      <button type="button" className="btn btn-primary btn-block" onClick={() => retry()}>다시 시도</button>
    </StatusScreen>
  );
}
