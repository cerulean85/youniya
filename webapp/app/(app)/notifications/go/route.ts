import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";
import { API_URL } from "@/lib/config";
import { ACCESS } from "@/lib/session";

// Opening a notification: mark it read, then go to its screen (only paths inside the app).
export async function GET(request: NextRequest) {
  const id = request.nextUrl.searchParams.get("id");
  const to = request.nextUrl.searchParams.get("to") ?? "/notifications";
  const token = (await cookies()).get(ACCESS)?.value;
  if (token && id) {
    await fetch(`${API_URL}/v1/me/notifications/read`, {
      method: "POST", cache: "no-store",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify({ ids: [id] }),
    }).catch(() => null);
  }
  const safe = to.startsWith("/") && !to.startsWith("//") ? to : "/notifications";
  return NextResponse.redirect(new URL(safe, request.url), 303);
}
