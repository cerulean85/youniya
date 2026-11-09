import type { Metadata } from "next";
import { ReasonActions } from "@/components/ReasonActions";
import { getInvites } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { requireOperator } from "@/lib/session";
import { inviteAction, invitesSetting } from "../owner-actions";
import { NewInvite } from "./NewInvite";

export const metadata: Metadata = { title: "초대 계정" };

// Figma A-11: operator-made accounts (App Store review), signed in with an id and password.
export default async function InvitesPage() {
  await requireOperator(["owner"]);
  const v = await getInvites();
  const review = v.items.find((i) => i.login_id.startsWith("review"));
  return (
    <>
      <div className="head">
        <div><h1>초대 계정</h1><p className="muted">App Store 심사처럼 운영자가 만든 계정만 아이디와 비밀번호로 들어와요.</p></div>
        <NewInvite />
      </div>
      <section className="card toggle-row">
        <div>
          <h2>초대 계정 로그인 (INVITE_LOGIN) · {v.enabled ? "켜짐" : "꺼짐"}</h2>
          <p className="muted">켜면 로그인 화면에 &lsquo;초대 계정으로 로그인&rsquo;이 보여요. 심사 기간에는 켜 두세요. 시도는 IP당 분당 10번으로 막아요.</p>
        </div>
        <ReasonActions action={invitesSetting.bind(null, !v.enabled)} buttons={[{ key: "toggle", label: v.enabled ? "끄기" : "켜기", primary: !v.enabled }]} />
      </section>
      <div className="card table-card">
        <table className="table">
          <thead><tr><th>아이디</th><th>메모</th><th>만든 날</th><th>마지막 로그인</th><th>상태</th><th /></tr></thead>
          <tbody>{v.items.map((i) => (
            <tr key={i.id}>
              <td>{i.login_id}</td><td>{i.memo}</td><td>{i.created_at}</td><td>{i.last_login_at ? dateTime(i.last_login_at) : "—"}</td>
              <td><span className={`badge ${i.enabled ? "badge-done" : "badge-muted"}`}>{i.enabled ? "켜짐" : "꺼짐"}</span></td>
              <td><ReasonActions action={inviteAction.bind(null, i.id)} buttons={[{ key: i.enabled ? "disable" : "enable", label: i.enabled ? "끄기" : "켜기" }]} /></td>
            </tr>
          ))}</tbody>
        </table>
      </div>
      {review && (
        <section className="card panel">
          <h2>심사용 데이터 다시 채우기</h2>
          <p className="muted">별 15개(별빛 받은 별·없는 별), 이번 달과 지난달 별자리, 별 잇기, 광장의 나눈 별과 별빛 한 줄을 다시 채워요. 제출 직전에 한 번 눌러 주세요.</p>
          <ReasonActions action={inviteAction.bind(null, review.id)} buttons={[{ key: "reseed", label: `${review.login_id}에 다시 채우기`, confirm: "지금 이 계정에 있는 별과 나눈 별은 지우고 새로 채워요." }]} />
        </section>
      )}
    </>
  );
}
