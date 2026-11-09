import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import { getPrism } from "@/lib/api";
import { num } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import type { PrismStatus } from "@/lib/types";

export const metadata: Metadata = { title: "별빛 측정 방식" };

const STATUS: Record<PrismStatus, [string, string]> = { draft: ["badge-muted", "준비"], held: ["badge-pending", "보류"], active: ["badge-done", "사용 중"], retired: ["badge-muted", "끝남"] };

// Figma A-10 (기획서 17.6): starlight already given is never recounted; a new prism ships only after it passes
// the 30-piece test, so 배포 stays off until then.
export default async function PrismPage() {
  await requireOperator(["owner"]);
  const wait = notConnected("owner", "별빛 측정 방식");
  if (wait) return wait;
  const p = await getPrism();
  const next = p.versions.find((v) => v.status === "held" || v.status === "draft");
  const t = p.test && next && p.test.version === next.key ? p.test : null;
  return (
    <>
      <div className="head">
        <div><h1>별빛 측정 방식</h1><p className="muted">이미 받은 별빛은 다시 계산하지 않아요. 새 방식은 시험을 통과해야 배포할 수 있어요.</p></div>
        {next && (
          <p className="faint" style={{ maxWidth: 360, textAlign: "right" }}>
            시험과 배포는 콘솔에서 하지 않아요. 시험은 서버의 tools/compare_prism.py(AI 약 120회)로, 배포는 코드로 해요. 결과는 여기에 남아요.
          </p>
        )}
      </div>
      <div className="card table-card">
        <table className="table">
          <thead><tr><th>버전</th><th>설명</th><th>배포</th><th>별</th><th>상태</th></tr></thead>
          <tbody>{p.versions.map((v) => (
            <tr key={v.key}><td>{v.label}</td><td>{v.description}</td><td>{v.deployed_at ?? "—"}</td><td>{v.stars != null ? num(v.stars) : "—"}</td><td><span className={`badge ${STATUS[v.status][0]}`}>{STATUS[v.status][1]}</span></td></tr>
          ))}</tbody>
        </table>
      </div>
      <div className="split">
        {t ? (
          <section className="card panel">
            <h2>{next!.label.replace("별빛 프리즘 ", "")} 시험 결과 · 시험용 글 {t.sample_size}편</h2>
            <dl className="kv">
              <dt>평균 별빛 차이</dt><dd>{t.starlight_diff >= 0 ? "+" : ""}{t.starlight_diff} (기준 ±{t.threshold})</dd>
              <dt>세 점수 순서</dt><dd>{t.rank_flips}편 뒤집힘 (기준: 크게 뒤집히지 않음)</dd>
              <dt>깊이 평균</dt><dd>{t.depth >= 0 ? "+" : ""}{t.depth}</dd>
              <dt>선명함 평균</dt><dd>{t.clarity >= 0 ? "+" : ""}{t.clarity}</dd>
              <dt>무게 평균</dt><dd>{t.weight >= 0 ? "+" : ""}{t.weight}</dd>
            </dl>
            <p className={t.passed ? "faint" : "rule"}>{t.passed ? "기준 안이에요. 배포할 수 있어요." : "기준을 넘어 배포할 수 없어요. 프롬프트를 고친 뒤 다시 시험해 주세요."}</p>
          </section>
        ) : <section className="card panel"><h2>시험 결과</h2><p className="muted">{next ? "아직 시험하지 않았어요." : "시험할 새 방식이 없어요."}</p></section>}
        <section className="card panel">
          <h2>배포 전 확인</h2>
          <ol className="steps">
            <li>시험용 글 30편으로 옛·새 방식 비교</li>
            <li>평균 차이 ±30 안, 순서 크게 안 뒤집힘</li>
            <li>운영자 승인 후 배포 · 별마다 버전 저장</li>
            <li>크게 바뀌면 별빛 흐름에 &lsquo;이때부터 새 방식&rsquo; 표시</li>
          </ol>
        </section>
      </div>
    </>
  );
}
