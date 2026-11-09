import "server-only";
import { ready, type Part } from "@/lib/config";

/** With a real API, a part that isn't live yet shows this instead of mock data. */
export function notConnected(part: Part, title: string) {
  if (ready(part)) return null;
  return (
    <>
      <div className="head"><div><h1>{title}</h1></div></div>
      <div className="card placeholder">
        <h2>서버 연결 대기</h2>
        <p className="muted">이 화면의 운영자 API가 아직 이 서버에 배포되지 않았어요. 배포되면 바로 열려요.</p>
      </div>
    </>
  );
}
