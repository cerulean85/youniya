import "server-only";
import { redirect } from "next/navigation";
import { api } from "./api";
import type { Me, PlazaStar } from "./types";

/** 기획서 15.1: the plaza needs a 별지기 이름; writing doesn't. */
export async function requireNickname(next: string): Promise<Me> {
  const me = await api<Me>("/v1/me");
  if (!me.nickname) redirect(`/nickname?next=${encodeURIComponent(next)}`);
  return me;
}

/** "방금" / "12분 전" / "1시간 전" / "2일 전", from one reading of the clock. */
export function withAgo(stars: PlazaStar[]) {
  const now = Date.now();
  return stars.map((star) => ({ star, ago: ago(star.created_at, now) }));
}

function ago(iso: string, now: number) {
  const m = Math.max(0, Math.round((now - new Date(iso).getTime()) / 60000));
  if (m < 1) return "방금";
  if (m < 60) return `${m}분 전`;
  if (m < 60 * 24) return `${Math.floor(m / 60)}시간 전`;
  return `${Math.floor(m / 60 / 24)}일 전`;
}
