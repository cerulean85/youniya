import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { connection } from "next/server";
import { Suspense } from "react";
import { StarFilled, Warn } from "@/components/icons";
import { StatusScreen } from "@/components/Status";
import { api, ApiError } from "@/lib/api";

export const metadata: Metadata = { title: "별빛 받기 그만두기" };
export const maxDuration = 60;

type Cancelled = { status: "cancelled"; star: { id: string } | null };
const ASK_MS = 2000, ASK_FOR_MS = 20_000;

// W-105 그만두기 lands here as a full load, which drops the request still waiting for the prism (so its result
// can't show). The cancel is safe to repeat: before the request reaches the server it answers star: null, and the
// request then saves the star and stops it, so asking again names that star. Nothing after 20 s: it never arrived.
export default function Stopping({ params, searchParams }: PageProps<"/starlight/[attempt]/stopping">) {
  return (
    <Suspense fallback={<StatusScreen icon={<StarFilled size={22} />} title="별빛 받기를 그만두는 중이에요" body="잠시만 기다려 주세요. 무료와 코인은 쓰지 않아요." />}>
      <Stop params={params} searchParams={searchParams} />
    </Suspense>
  );
}

async function Stop({ params, searchParams }: Pick<PageProps<"/starlight/[attempt]/stopping">, "params" | "searchParams">) {
  const [{ attempt }, sp] = await Promise.all([params, searchParams, connection()]);
  const until = Date.now() + ASK_FOR_MS;
  let star: string | null = null, code: string | null = null;
  for (;;) {
    try {
      const r = await api<Cancelled>(`/v1/starlight/attempts/${encodeURIComponent(attempt)}/cancel`, { method: "POST" });
      star = r.star?.id ?? null;
    } catch (e) {
      if (!(e instanceof ApiError)) throw e;
      code = e.code;
    }
    if (star || code || Date.now() > until) break;
    await new Promise((ok) => setTimeout(ok, ASK_MS));
  }
  if (star) {
    // Writing a new star: the writing is that star now, so the draft goes.
    if (sp.draft === "1") await api("/v1/drafts/current", { method: "DELETE" }).catch(() => null);
    redirect(`/stars/${star}?stopped=1`);
  }
  if (!code) redirect(sp.draft === "1" ? "/write?stopped=1" : "/records");
  // 409 cancel_too_late: the reading finished over a minute ago and its starlight stays.
  return (
    <StatusScreen icon={<Warn size={22} />} title={code === "cancel_too_late" ? "이미 별빛을 받았어요" : "그만두지 못했어요"}
      body={code === "cancel_too_late" ? "별빛 받기가 끝난 뒤라 그만둘 수 없어요. 받은 별빛은 그대로 남아요." : "잠시 뒤에 기록에서 별을 확인해 주세요."}>
      <Link href="/records" className="btn btn-primary btn-block">기록으로 가기</Link>
    </StatusScreen>
  );
}
