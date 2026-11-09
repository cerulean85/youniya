import type { Metadata } from "next";
import { Stat } from "@/components/Stat";
import { getAi } from "@/lib/api";
import { monthLabel, num, thisMonth, won } from "@/lib/format";
import { requireOperator } from "@/lib/session";

export const metadata: Metadata = { title: "AI 사용량·원가" };

// Figma A-09 (owners): what the starlight prism and the telescope cost, and members over the monthly line.
export default async function AiPage() {
  await requireOperator(["owner"]);
  const month = thisMonth();
  const a = await getAi(month);
  const s = a.summary;
  return (
    <>
      <div className="head">
        <div><h1>AI 사용량·원가</h1><p className="muted">모델 {a.model} · 생각 설정 {a.thinking} · 1달러 = {num(a.krw_per_usd)}원으로 계산</p></div>
        <span className="btn">기간: {monthLabel(month)}</span>
      </div>
      <div className="stats five">
        <Stat label="이번 달 원가" value={won(s.cost_krw)} sub={`지난달 같은 날보다 ${s.change_pct >= 0 ? "+" : ""}${s.change_pct}%`} />
        <Stat label="호출" value={num(s.calls)} sub={`실패 ${s.failure_rate}% · 코인·무료 몫 차감 안 함`} />
        <Stat label="별빛 받기 1회" value={won(s.per_starlight_krw)} sub={`직접 캐시 적중 ${s.cache_hit}%`} />
        <Stat label="마음 망원경 1회" value={won(s.per_telescope_krw)} />
        <Stat label="멤버 원가 경보" value={`${s.member_alerts}명`} tone={s.member_alerts ? "red" : undefined} sub={`월 ${won(s.member_limit_krw)} 넘음`} />
      </div>
      <div className="split">
        <div className="card table-card">
          <table className="table">
            <thead><tr><th>기능</th><th>호출</th><th>평균 입력</th><th>평균 출력</th><th>원가</th></tr></thead>
            <tbody>{a.features.map((f) => (
              <tr key={f.key}><td>{f.label}</td><td>{f.calls != null ? num(f.calls) : "—"}</td><td>{f.avg_in != null ? num(f.avg_in) : f.note ?? "—"}</td><td>{f.avg_out != null ? num(f.avg_out) : "—"}</td><td>{won(f.cost_krw)}</td></tr>
            ))}</tbody>
          </table>
        </div>
        <div className="card table-card">
          <table className="table">
            <thead><tr><th>별지기</th><th>이번 달</th><th>상태</th></tr></thead>
            <tbody>{a.members.map((m) => (
              <tr key={m.keeper_no}><td>{m.keeper_no}</td><td>{won(m.cost_krw)}</td><td><span className={`badge ${m.alert ? "badge-hidden" : "badge-done"}`}>{m.alert ? "경보" : "정상"}</span></td></tr>
            ))}</tbody>
          </table>
        </div>
      </div>
    </>
  );
}
