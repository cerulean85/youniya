import type { Metadata } from "next";
import { ReasonActions } from "@/components/ReasonActions";
import { getNotices } from "@/lib/api";
import { requireOperator } from "@/lib/session";
import { noticesAction } from "../owner-actions";

export const metadata: Metadata = { title: "공지·점검" };

const STATUS = { live: ["badge-done", "게시 중"], scheduled: ["badge-pending", "예약"], ended: ["badge-muted", "끝남"] } as const;
const AUDIENCE = { all: "전체", ios: "iOS", web: "웹" } as const;

// Figma A-12: maintenance and the minimum version apply at once (app screens 41 점검, 40 업데이트 필요).
export default async function NoticesPage() {
  await requireOperator(["owner"]);
  const n = await getNotices();
  const today = new Date().toISOString().slice(0, 10);
  return (
    <>
      <div className="head">
        <div><h1>공지·점검</h1><p className="muted">점검과 최소 버전은 바로 적용돼요. 앱 화면 41 서비스 점검, 40 업데이트 필요로 이어져요.</p></div>
        <ReasonActions action={noticesAction} buttons={[{ key: "notice", label: "새 공지", primary: true, fields: [
          { name: "title", label: "제목", required: true },
          { name: "body", label: "내용", type: "textarea", required: true },
          { name: "audience", label: "대상", type: "select", options: [["all", "전체"], ["ios", "iOS"], ["web", "웹"]], defaultValue: "all" },
          { name: "starts_at", label: "시작", type: "date", required: true, defaultValue: today },
          { name: "ends_at", label: "끝", type: "date", required: true, defaultValue: today },
        ] }]} />
      </div>
      <section className="card toggle-row">
        <div>
          <h2>서비스 점검 모드 · {n.maintenance.on ? "켜짐" : "꺼짐"}</h2>
          <p className="muted">켜면 앱과 웹에서 점검 화면을 보여 줘요. 쓰던 글은 기기에 임시 저장돼요.</p>
        </div>
        <ReasonActions action={noticesAction} buttons={[n.maintenance.on
          ? { key: "maintenance_off", label: "점검 끝내기", primary: true }
          : { key: "maintenance_on", label: "점검 시작", danger: true, confirm: "지금 모든 별지기가 앱과 웹을 쓸 수 없게 돼요." }]} />
      </section>
      <div className="split rev">
        <section className="card panel">
          <h2>최소 앱 버전</h2>
          <dl className="kv"><dt>iOS</dt><dd>{n.min_version.ios} (이보다 낮으면 업데이트 필요)</dd><dt>웹</dt><dd>항상 최신</dd></dl>
          <ReasonActions action={noticesAction} buttons={[{ key: "min_version", label: "바꾸기", fields: [{ name: "ios", label: "iOS 최소 버전", required: true, defaultValue: n.min_version.ios }], confirm: "이보다 낮은 앱은 바로 업데이트 화면으로 막혀요." }]} />
        </section>
        <div className="card table-card">
          <table className="table">
            <thead><tr><th>제목</th><th>대상</th><th>기간</th><th>상태</th></tr></thead>
            <tbody>{n.items.map((x) => (
              <tr key={x.id}><td>{x.title}</td><td>{AUDIENCE[x.audience]}</td><td>{x.starts_at.slice(5)} ~ {x.ends_at.slice(5)}</td><td><span className={`badge ${STATUS[x.status][0]}`}>{STATUS[x.status][1]}</span></td></tr>
            ))}</tbody>
          </table>
        </div>
      </div>
    </>
  );
}
