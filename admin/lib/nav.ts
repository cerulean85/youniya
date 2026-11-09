import type { Role } from "./types";

// Figma Admin › Admin Sidebar. Moderators get 신고 처리, 별지기 and 문의 only (기획서 18.1, A-14); the rest is hidden.
export type NavItem = { href: string; label: string; roles: Role[]; figma: string; ready?: boolean };
const BOTH: Role[] = ["owner", "moderator"], OWNER: Role[] = ["owner"];
export const NAV: NavItem[] = [
  { href: "/dashboard", label: "대시보드", roles: OWNER, figma: "A-02" },
  { href: "/reports", label: "신고 처리", roles: BOTH, figma: "A-03", ready: true },
  { href: "/keepers", label: "별지기", roles: BOTH, figma: "A-05" },
  { href: "/inquiries", label: "문의", roles: BOTH, figma: "A-07" },
  { href: "/coins", label: "코인·결제", roles: OWNER, figma: "A-08" },
  { href: "/ai", label: "AI 사용량·원가", roles: OWNER, figma: "A-09" },
  { href: "/prism", label: "별빛 측정 방식", roles: OWNER, figma: "A-10" },
  { href: "/invites", label: "초대 계정", roles: OWNER, figma: "A-11" },
  { href: "/notices", label: "공지·점검", roles: OWNER, figma: "A-12" },
  { href: "/audit", label: "운영 기록", roles: OWNER, figma: "A-13", ready: true },
  { href: "/operators", label: "운영자·권한", roles: OWNER, figma: "A-14" },
];
