import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { API_URL } from "@/lib/config";
import { ACCESS } from "@/lib/session";

// 93 데이터 내보내기: every star as a text file, passed straight through from the API.
export async function GET(request: Request) {
  const token = (await cookies()).get(ACCESS)?.value;
  if (!token) return NextResponse.redirect(new URL("/login", request.url));
  const res = await fetch(`${API_URL}/v1/me/export?format=text`, { headers: { Authorization: `Bearer ${token}` }, cache: "no-store" });
  if (!res.ok) return new NextResponse("내보내지 못했어요. 잠시 뒤에 다시 시도해 주세요.", { status: res.status, headers: { "Content-Type": "text/plain; charset=utf-8" } });
  return new NextResponse(res.body, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Content-Disposition": `attachment; filename="youniya.txt"; filename*=UTF-8''${encodeURIComponent("YOUNIYA 기록.txt")}`,
      "Cache-Control": "no-store",
    },
  });
}
