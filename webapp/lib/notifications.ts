import type { AppNotification, NotificationTarget } from "./types";

/** Where a notification leads (Mobile 130 target.screen). */
export function targetHref(t: NotificationTarget | null): string | null {
  if (!t) return null;
  switch (t.screen) {
    case "star": return t.star_id ? `/stars/${t.star_id}` : null;
    case "nickname": return "/settings/nickname";
    case "plaza_restricted": return "/plaza?restricted=1";
    case "plaza": return "/plaza";
    case "coin_history": return "/coins";
    case "notice": return t.notice_id ? `/notices/${t.notice_id}` : null;
    case "notification_settings": return "/settings";
    case "notifications": return "/notifications";
    default: return null;
  }
}

/** The small label and colour above a notification's title, and what its link says. */
export const KIND: Record<string, { label: string; color: string; action?: string }> = {
  notice: { label: "공지", color: "var(--primary-text)", action: "공지 보기" },
  rename_requested: { label: "운영자 요청", color: "var(--gold)", action: "이름 바꾸기" },
  rename_request: { label: "운영자 요청", color: "var(--gold)", action: "이름 바꾸기" },
  plaza_restricted: { label: "이용 제한", color: "var(--anger)", action: "자세히" },
  taken_down: { label: "광장에서 내려감", color: "var(--anger)", action: "별 보기" },
  share_taken_down: { label: "광장에서 내려감", color: "var(--anger)", action: "별 보기" },
  report_result: { label: "신고 처리 결과", color: "var(--calm)" },
  coins: { label: "코인", color: "var(--cyan)", action: "코인 사용 내역" },
  coin_grant: { label: "코인", color: "var(--cyan)", action: "코인 사용 내역" },
  consent_result: { label: "알림 동의", color: "var(--text-3)", action: "알림 설정" },
};
/** Unknown kinds still link, named by where they lead. */
const BY_SCREEN: Record<string, string> = { star: "별 보기", nickname: "이름 바꾸기", plaza_restricted: "자세히", plaza: "광장 보기", coin_history: "코인 사용 내역", notice: "공지 보기", notification_settings: "알림 설정", notifications: "알림 보기" };
export const kindOf = (n: AppNotification) => KIND[n.kind] ?? { label: "알림", color: "var(--text-3)", action: n.target ? BY_SCREEN[n.target.screen] : undefined };
