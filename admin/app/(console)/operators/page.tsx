import type { Metadata } from "next";
import { notConnected } from "@/components/NotConnected";
import { ReasonActions, type ReasonButton } from "@/components/ReasonActions";
import { getOperators } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import { operatorsAction } from "../owner-actions";

export const metadata: Metadata = { title: "운영자·권한" };

const STATUS = { active: ["badge-done", "사용 중"], invited: ["badge-pending", "초대 대기"], disabled: ["badge-muted", "멈춤"] } as const;
// The A-14 table: what 전체 (owner) and 신고 처리 (moderator) may do.
const ABILITIES: [string, boolean][] = [
  ["신고 처리 · 숨김 풀기 · 광장에서 내리기", true], ["별지기 상세 보기 · 광장 이용 제한", true], ["문의 답장", true],
  ["코인 지급", false], ["별빛 측정 방식 시험·배포", false], ["초대 계정 · 점검 모드 · 최소 버전", false],
  ["계정 삭제 요청 처리", false], ["운영자 초대 · 권한 바꾸기", false],
];

// Figma A-14: operators join by invitation only and need two-step sign-in.
export default async function OperatorsPage() {
  const { operator: me } = await requireOperator(["owner"]);
  const wait = notConnected("operators", "운영자·권한");
  if (wait) return wait;
  const ops = await getOperators();
  return (
    <>
      <div className="head">
        <div><h1>운영자·권한</h1><p className="muted">admin.youniya.dycdyp.com · 운영자는 초대로만 추가돼요. 모두 2단계 인증을 켜야 들어올 수 있어요.</p></div>
        <ReasonActions action={operatorsAction.bind(null, null)} buttons={[{ key: "invite", label: "운영자 초대", primary: true, fields: [
          { name: "email", label: "이메일", required: true },
          { name: "role", label: "권한", type: "select", options: [["moderator", "신고 처리"], ["owner", "전체"]], defaultValue: "moderator" },
        ] }]} />
      </div>
      <div className="card table-card">
        <table className="table">
          <thead><tr><th>운영자</th><th>이메일</th><th>권한</th><th>2단계 인증</th><th>마지막 접속</th><th>상태</th><th /></tr></thead>
          <tbody>{ops.map((o) => {
            const self = o.id === me.id;
            const buttons: ReasonButton[] = self ? [] : [
              o.role === "owner" ? { key: "make_moderator", label: "신고 처리로" } : { key: "make_owner", label: "전체로", confirm: "모든 메뉴와 조치를 쓸 수 있게 돼요." },
              o.status === "disabled" ? { key: "enable", label: "다시 쓰기" } : { key: "disable", label: "멈추기", danger: true },
            ];
            return (
              <tr key={o.id}>
                <td>{o.name}{self ? " (나)" : ""}</td><td>{o.email_masked}</td><td>{o.role === "owner" ? "전체" : "신고 처리"}</td>
                <td>{o.totp ? "켜짐" : "—"}</td><td>{o.last_seen_at ? dateTime(o.last_seen_at) : "—"}</td>
                <td><span className={`badge ${STATUS[o.status][0]}`}>{STATUS[o.status][1]}</span></td>
                <td>{buttons.length > 0 && <ReasonActions action={operatorsAction.bind(null, o.id)} buttons={buttons} />}</td>
              </tr>
            );
          })}</tbody>
        </table>
      </div>
      <div className="card table-card">
        <table className="table">
          <thead><tr><th>할 수 있는 일</th><th>전체</th><th>신고 처리</th></tr></thead>
          <tbody>{ABILITIES.map(([what, mod]) => (
            <tr key={what}><td>{what}</td><td><span className="badge badge-done">가능</span></td><td><span className={`badge ${mod ? "badge-done" : "badge-hidden"}`}>{mod ? "가능" : "불가"}</span></td></tr>
          ))}</tbody>
        </table>
      </div>
    </>
  );
}
