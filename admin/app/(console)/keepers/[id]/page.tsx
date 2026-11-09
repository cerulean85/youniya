import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ReasonActions, type ReasonButton } from "@/components/ReasonActions";
import { ApiError, getKeeper } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import { ACTION_LABEL, KEEPER_ACTION_LABEL, MODERATOR_KEEPER_ACTIONS, PROVIDER_LABEL, type KeeperDetail } from "@/lib/types";
import { actOnKeeper } from "./actions";

export const metadata: Metadata = { title: "별지기 상세" };

const day = (iso: string) => new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", month: "long", day: "numeric" }).format(new Date(iso));

// Figma A-06: account facts, consents and sanctions; never what they wrote.
export default async function KeeperPage({ params }: PageProps<"/keepers/[id]">) {
  const { operator } = await requireOperator();
  const wait = notConnected("keepers", "별지기 상세");
  if (wait) return wait;
  const { id } = await params;
  let k: KeeperDetail;
  try {
    k = await getKeeper(decodeURIComponent(id));
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  const all: ReasonButton[] = [
    ...(k.status === "restricted" ? [{ key: "lift_restriction", label: KEEPER_ACTION_LABEL.lift_restriction }] : []),
    { key: "extend_restriction", label: k.status === "restricted" ? "제한 늘리기" : "광장 이용 제한", danger: true, field: "days" },
    ...(k.nickname ? [{ key: "request_rename", label: KEEPER_ACTION_LABEL.request_rename }] : []),
    { key: "grant_coins", label: "코인 지급 (사유 필수)", field: "amount" },
    ...(k.deletion_requested_at ? [{ key: "process_deletion", label: KEEPER_ACTION_LABEL.process_deletion, danger: true, confirm: "별, 나눈 별, 받은 별빛 한 줄, 코인이 모두 지워지고 되돌릴 수 없어요. 결제 기록만 5년 보관해요." }] : []),
  ] as ReasonButton[];
  const buttons = operator.role === "owner" ? all : all.filter((b) => MODERATOR_KEEPER_ACTIONS.includes(b.key as never));
  const m = k.consents.marketing;
  return (
    <>
      <div className="head">
        <div>
          <h1>{k.nickname ?? "이름 없음"} · {k.no}</h1>
          <p className="muted">가입 {k.joined_at.slice(0, 10)} · {PROVIDER_LABEL[k.provider] ?? k.provider} 로그인{k.last_seen_at ? ` · 마지막 접속 ${dateTime(k.last_seen_at)}` : ""}</p>
        </div>
        <Link href="/keepers" className="btn">‹ 목록</Link>
      </div>
      <div className="cols">
        <div className="stack">
          <div className="stats">
            <div className="card stat"><span className="faint">띄운 별</span><b>{k.stars}</b><span className="faint">별빛 받음 {k.star_counts.lit} · 없음 {k.star_counts.unlit}</span></div>
            <div className="card stat"><span className="faint">나눈 별</span><b>{k.shared}</b></div>
            <div className="card stat"><span className="faint">받은 신고</span><b style={k.reports ? { color: "var(--amber)" } : undefined}>{k.reports}</b></div>
            <div className="card stat"><span className="faint">코인</span><b>{k.coins.toLocaleString("ko-KR")}</b></div>
          </div>
          <section className="card panel">
            <h2>계정</h2>
            <dl className="kv">
              <dt>약관 동의</dt><dd>{k.consents.terms_at ? `${dateTime(k.consents.terms_at)}${k.consents.terms_version ? ` (${k.consents.terms_version})` : ""}` : "—"}</dd>
              <dt>민감정보 동의</dt><dd>{k.consents.sensitive_at ? dateTime(k.consents.sensitive_at) : "—"}</dd>
              <dt>혜택 알림</dt><dd>{m.opt_in ? `동의 · ${m.at ? dateTime(m.at) : ""}` : "동의 안 함"}</dd>
              <dt>별지기 이름</dt><dd>{k.nickname ? `${k.nickname}${k.nickname_next_change ? ` · 다음 변경 가능 ${day(k.nickname_next_change)}` : ""}` : "정하지 않음"}</dd>
              <dt>상태</dt><dd>{k.status === "restricted" && k.restricted_until ? `광장 이용 제한 · ${day(k.restricted_until)}까지` : "정상"}</dd>
              {k.deletion_requested_at && <><dt>삭제 요청</dt><dd style={{ color: "var(--red)" }}>{dateTime(k.deletion_requested_at)}에 요청</dd></>}
            </dl>
          </section>
          <section className="card table-card">
            <table className="table">
              <thead><tr><th>날짜</th><th>조치</th><th>사유</th><th>운영자</th></tr></thead>
              <tbody>
                {k.history.length === 0 ? <tr><td colSpan={4} className="muted">조치 기록이 없어요.</td></tr> : k.history.map((h, i) => (
                  <tr key={i}><td>{dateTime(h.at)}</td><td>{ACTION_LABEL[h.action] ?? KEEPER_ACTION_LABEL[h.action as never] ?? h.action}</td><td>{h.reason}</td><td>{h.operator.split("@")[0]}</td></tr>
                ))}
              </tbody>
            </table>
          </section>
        </div>
        <aside className="card panel">
          <h2>조치</h2>
          <p className="muted">모든 조치에는 사유를 꼭 적어요. 별지기에게 알림이 가요.</p>
          <ReasonActions buttons={buttons} action={actOnKeeper.bind(null, k.id)} />
          {operator.role !== "owner" && <p className="faint">코인 지급과 계정 삭제 처리는 운영자(owner)만 할 수 있어요.</p>}
        </aside>
      </div>
    </>
  );
}
