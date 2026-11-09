import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { API_URL } from "@/lib/config";
import { ACCESS } from "@/lib/session";

// 93 데이터 내보내기: every star (with its 별빛 풀이, telescope result and links) as text or PDF, passed through.
export async function GET(request: Request) {
  const token = (await cookies()).get(ACCESS)?.value;
  if (!token) return NextResponse.redirect(new URL("/login", request.url));
  const pdf = new URL(request.url).searchParams.get("format") === "pdf";
  const res = await fetch(`${API_URL}/v1/me/export?format=${pdf ? "pdf" : "text"}`, { headers: { Authorization: `Bearer ${token}` }, cache: "no-store" });
  if (!res.ok) return new NextResponse("내보내지 못했어요. 잠시 뒤에 다시 시도해 주세요.", { status: res.status, headers: { "Content-Type": "text/plain; charset=utf-8" } });
  return new NextResponse(res.body, {
    headers: {
      "Content-Type": pdf ? "application/pdf" : "text/plain; charset=utf-8",
      "Content-Disposition": `attachment; filename="youniya.${pdf ? "pdf" : "txt"}"; filename*=UTF-8''${encodeURIComponent(`YOUNIYA 기록.${pdf ? "pdf" : "txt"}`)}`,
      "Cache-Control": "no-store",
    },
  });
}
