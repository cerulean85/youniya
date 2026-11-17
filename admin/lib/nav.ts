import type { Role } from "./types";

// Figma Admin v2/Sidebar (2026-11-17): grouped as 처리할 일 · 돈 · 서비스 · 기록·권한.
// Moderators get 신고 처리, 문의 and 별지기 only (기획서 18.1, A-14); the rest is hidden.
export type NavGroup = "" | "처리할 일" | "돈" | "서비스" | "기록·권한";
export type NavItem = { href: string; label: string; roles: Role[]; figma: string; group: NavGroup; ready?: boolean };
const BOTH: Role[] = ["owner", "moderator"], OWNER: Role[] = ["owner"];
export const NAV: NavItem[] = [
  { href: "/dashboard", label: "대시보드", roles: OWNER, figma: "A-02", group: "", ready: true },
  { href: "/reports", label: "신고 처리", roles: BOTH, figma: "A-03", group: "처리할 일", ready: true },
  { href: "/inquiries", label: "문의", roles: BOTH, figma: "A-07", group: "처리할 일", ready: true },
  { href: "/keepers", label: "별지기", roles: BOTH, figma: "A-05", group: "처리할 일", ready: true },
  { href: "/coins", label: "코인·결제", roles: OWNER, figma: "A-08", group: "돈", ready: true },
  { href: "/ai", label: "AI 사용량·원가", roles: OWNER, figma: "A-09", group: "돈", ready: true },
  { href: "/notices", label: "공지·점검", roles: OWNER, figma: "A-12", group: "서비스", ready: true },
  { href: "/prism", label: "별빛 측정 방식", roles: OWNER, figma: "A-10", group: "서비스", ready: true },
  { href: "/invites", label: "초대 계정", roles: OWNER, figma: "A-11", group: "서비스", ready: true },
  { href: "/audit", label: "운영 기록", roles: OWNER, figma: "A-13", group: "기록·권한", ready: true },
  { href: "/operators", label: "운영자·권한", roles: OWNER, figma: "A-14", group: "기록·권한", ready: true },
];
