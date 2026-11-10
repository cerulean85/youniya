import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";
import { API_URL } from "@/lib/config";
import { ACCESS } from "@/lib/session";

// Toss sends the buyer back here with paymentKey, orderId and amount. The server checks the amount against
// its order, confirms with Toss (secret key) and grants the coins once, however often this is hit.
export async function GET(request: NextRequest) {
  const q = request.nextUrl.searchParams;
  const paymentKey = q.get("paymentKey"), orderId = q.get("orderId"), amount = Number(q.get("amount"));
  const back = (path: string) => NextResponse.redirect(new URL(path, request.url), 303);
  if (!paymentKey || !orderId || !Number.isFinite(amount)) return back("/coins/fail?code=INVALID_REQUEST");
  const token = (await cookies()).get(ACCESS)?.value;
  if (!token) return back("/login?next=/coins");
  const confirm = () => fetch(`${API_URL}/v1/payments/toss/confirm`, {
    method: "POST", cache: "no-store",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ payment_key: paymentKey, order_id: orderId, amount }),
  }).catch(() => null);
  // 502 payment_unconfirmed: Toss didn't answer; the same confirm again is safe (granted once).
  let res = await confirm();
  if (!res || res.status === 502) res = await confirm();
  if (!res?.ok) {
    const err = res ? ((await res.json().catch(() => null))?.error ?? {}) : {};
    return back(`/coins/fail?${new URLSearchParams({ code: err.code ?? "CONFIRM_FAILED", message: err.message ?? "결제를 확인하지 못했어요." })}`);
  }
  const r = await res.json().catch(() => ({}));
  // W-84 충전이 끝났어요, with the way back to whatever needed the coins.
  const from = q.get("from");
  return back(`/coins/done?${new URLSearchParams({ added: String(r.granted ?? ""), ...(from && { from }) })}`);
}
