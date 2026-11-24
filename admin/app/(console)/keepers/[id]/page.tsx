import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ReasonActions, type ReasonButton } from "@/components/ReasonActions";
import { Stat } from "@/components/Stat";
import { ApiError, getKeeper, keeperOrders } from "@/lib/api";
import { ready } from "@/lib/config";
import { dateTime } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import { ACTION_LABEL, KEEPER_ACTION_LABEL, MODERATOR_KEEPER_ACTIONS, ORDER_STATUS_LABEL, PROVIDER_LABEL, REFUND_BLOCK_LABEL, type KeeperDetail, type KeeperOrder } from "@/lib/types";
import { actOnKeeper, refund } from "./actions";

export const metadata: Metadata = { title: "별지기 상세" };

const day = (iso: string) => new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", month: "long", day: "numeric" }).format(new Date(iso));

// Figma A2-04 (A-06): account facts, consents and sanctions; never what they wrote.
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
  const owner = operator.role === "owner";
  const all: ReasonButton[] = [
    ...(k.status === "restricted" ? [{ key: "lift_restriction", label: KEEPER_ACTION_LABEL.lift_restriction, group: "광장 이용" }] : []),
    { key: "extend_restriction", label: k.status === "restricted" ? "제한 늘리기" : "광장 이용 제한", danger: true, field: "days", group: "광장 이용" },
    ...(k.nickname ? [{ key: "request_rename", label: KEEPER_ACTION_LABEL.request_rename, group: "이름" }] : []),
    { key: "grant_coins", label: "코인 지급", field: "amount", group: "코인 · owner" },
    ...(k.coins > 0 ? [{ key: "revoke_coins", label: "코인 회수", danger: true, field: "amount", group: "코인 · owner", confirm: `남은 코인 ${k.coins.toLocaleString("ko-KR")}개 안에서 회수해요. 결제 환불이 아니라 잘못 지급한 코인을 되돌릴 때 써요. 별지기에게 알림이 가요.` }] : []),
    ...(k.deletion_requested_at ? [{ key: "process_deletion", label: KEEPER_ACTION_LABEL.process_deletion, danger: true, group: "계정 · owner", confirm: "별, 나눈 별, 받은 별빛 한 줄, 코인이 모두 지워지고 되돌릴 수 없어요. 결제 기록만 5년 보관해요." }] : []),
  ] as ReasonButton[];
  const buttons = owner ? all : all.filter((b) => MODERATOR_KEEPER_ACTIONS.includes(b.key as never));
  const m = k.consents.marketing;
  // 운영자 환불: until the API ships it, a live console shows the section as waiting rather than mock orders.
  const orders: KeeperOrder[] | null = ready("payments") ? await keeperOrders(k.id).catch(() => null) : null;
  const who = `${k.nickname ?? "이름 없음"} · ${k.no}`;
  const krw = (n: number) => `${n.toLocaleString("ko-KR")}원`;
  const refundButton = (o: KeeperOrder): ReasonButton => {
    const taken = o.refundable ? o.coins : Math.min(o.coins, k.coins);
    const details: [string, string][] = [
      ["별지기", who],
      ["결제", `${krw(o.amount)} · 코인 ${o.coins.toLocaleString("ko-KR")}개 · 토스`],
      ["남은 코인", `${k.coins.toLocaleString("ko-KR")}개 → ${Math.max(0, k.coins - taken).toLocaleString("ko-KR")}개`],
    ];
    const base = { key: "refund", danger: true, details, title: `${day(o.approved_at ?? o.created_at)} 결제를 환불할까요?`, submit: `${krw(o.amount)} 환불` };
    return o.refundable
      ? { ...base, label: "환불", confirm: `${o.amount.toLocaleString("ko-KR")}원을 토스에서 취소하고 코인 ${o.coins}개를 회수해요. 되돌릴 수 없어요.` }
      : { ...base, label: "예외 환불", confirm: `${REFUND_BLOCK_LABEL[o.refund_block!] ?? "규칙 밖"} — 규칙상 환불 대상이 아니에요. 서비스 장애 같은 예외일 때만 써요. ${o.amount.toLocaleString("ko-KR")}원 전액을 취소하고, 코인은 남은 만큼(최대 ${o.coins}개)만 회수해요.` };
  };
  return (
    <>
      <div className="head">
        <div>
          <h1>{who}</h1>
          <p className="muted">가입 {k.joined_at.slice(0, 10)} · {PROVIDER_LABEL[k.provider] ?? k.provider} 로그인{k.last_seen_at ? ` · 마지막 접속 ${dateTime(k.last_seen_at)}` : ""}</p>
        </div>
        <Link href="/keepers" className="btn-text">‹ 목록</Link>
      </div>
      <div className="now">
        {k.deletion_requested_at && <span className="badge badge-hidden">삭제 요청 · {dateTime(k.deletion_requested_at)}</span>}
        <span className={`badge ${k.status === "restricted" ? "badge-pending" : "badge-muted"}`}>{k.status === "restricted" && k.restricted_until ? `광장 이용 제한 · ${day(k.restricted_until)}까지` : "정상"}</span>
        <span className="muted">받은 신고 {k.reports}건</span>
      </div>
      <div className="cols narrow">
        <div className="stack">
          <div className="strip">
            <Stat label="띄운 별" value={k.stars} sub={`별빛 받음 ${k.star_counts.lit} · 없음 ${k.star_counts.unlit}`} />
            <Stat label="나눈 별" value={k.shared} />
            <Stat label="받은 신고" value={k.reports} tone={k.reports ? "amber" : undefined} />
            <Stat label="코인" value={k.coins.toLocaleString("ko-KR")} />
          </div>
          <section className="section">
            <h2>계정</h2>
            <dl className="rows">
              <div><dt>로그인 이메일</dt><dd>{k.email ?? <span className="faint">받지 않음</span>}</dd></div>
              <div><dt>약관 동의</dt><dd>{k.consents.terms_at ? `${dateTime(k.consents.terms_at)}${k.consents.terms_version ? ` (${k.consents.terms_version})` : ""}` : "—"}</dd></div>
              <div><dt>민감정보 동의</dt><dd>{k.consents.sensitive_at ? dateTime(k.consents.sensitive_at) : "—"}</dd></div>
              <div><dt>혜택 알림</dt><dd>{m.opt_in ? `동의 · ${m.at ? dateTime(m.at) : ""}` : "동의 안 함"}</dd></div>
              <div><dt>별지기 이름</dt><dd>{k.nickname ? `${k.nickname}${k.nickname_next_change ? ` · 다음 변경 가능 ${day(k.nickname_next_change)}` : ""}` : "정하지 않음"}</dd></div>
              <div><dt>상태</dt><dd>{k.status === "restricted" && k.restricted_until ? `광장 이용 제한 · ${day(k.restricted_until)}까지` : "정상"}</dd></div>
              {k.deletion_requested_at && <div><dt>삭제 요청</dt><dd style={{ color: "var(--red)" }}>{dateTime(k.deletion_requested_at)}에 요청</dd></div>}
            </dl>
          </section>
          <section className="section">
            <h2>웹 결제 (토스)</h2>
            {!ready("payments") ? <p className="muted">운영자 환불 API가 아직 이 서버에 배포되지 않았어요. 배포되면 바로 열려요.</p>
              : orders == null ? <p className="muted">결제 내역을 불러오지 못했어요.</p> : (
              <table className="table">
                <thead><tr><th>날짜</th><th className="num">코인</th><th className="num">금액</th><th>상태</th><th className="act">{owner ? "환불" : ""}</th></tr></thead>
                <tbody>
                  {orders.length === 0 ? <tr><td colSpan={5} className="muted">웹 결제가 없어요. App Store 환불은 애플에서 처리돼요.</td></tr> : orders.map((o) => (
                    <tr key={o.id}>
                      <td>{dateTime(o.approved_at ?? o.created_at)}{o.method ? <span className="faint"> · {o.method}</span> : null}</td>
                      <td className="num">{o.coins.toLocaleString("ko-KR")}</td>
                      <td className="num">{krw(o.amount)}</td>
                      <td>{ORDER_STATUS_LABEL[o.status] ?? o.status}{o.canceled_at ? ` · ${dateTime(o.canceled_at)}` : ""}{o.refund_block && o.status === "done" ? <span className="faint"> · {REFUND_BLOCK_LABEL[o.refund_block] ?? o.refund_block}</span> : null}</td>
                      <td className="act">{owner && o.status === "done" && (
                        <ReasonActions look="text" action={refund.bind(null, o.id, !o.refundable)} buttons={[o.refundable ? refundButton(o) : { ...refundButton(o), quiet: true }]} />
                      )}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            {ready("payments") && orders != null && <p className="faint">결제 후 7일 안에, 그 결제로 받은 코인을 쓰지 않았을 때 환불해요. 예외 환불은 서비스 장애처럼 규칙 밖에서 돌려드려야 할 때만 써요. App Store 결제는 애플에서 환불돼요.</p>}
          </section>
          <section className="section">
            <h2>조치 기록</h2>
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
        <aside className="panel">
          <h2>조치</h2>
          <p className="muted">모든 조치에는 사유를 꼭 적어요. 별지기에게 알림이 가요.</p>
          <ReasonActions look="rows" buttons={buttons} action={actOnKeeper.bind(null, k.id)} />
          {!owner && <p className="faint">코인 지급·회수, 결제 환불과 계정 삭제 처리는 운영자(owner)만 할 수 있어요.</p>}
        </aside>
      </div>
    </>
  );
}
