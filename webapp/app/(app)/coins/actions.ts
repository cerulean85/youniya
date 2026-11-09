"use server";

import { api, ApiError } from "@/lib/api";

export type Order = { order_id: string; amount: number; order_name: string; customer_key: string };
export type OrderResult = { order?: Order; error?: string; soon?: boolean };

/** Toss (API 개별 연동): the server makes the order and its amount; the browser only opens the payment window. */
export async function createOrder(packageId: string): Promise<OrderResult> {
  try {
    return { order: await api<Order>("/v1/payments/toss/orders", { method: "POST", body: JSON.stringify({ package_id: packageId }) }) };
  } catch (e) {
    if (e instanceof ApiError && (e.status === 404 || e.status === 405) && e.code !== "not_found_package") return { soon: true, error: "웹 결제는 곧 열려요." };
    if (e instanceof ApiError) return { error: e.message };
    throw e;
  }
}
