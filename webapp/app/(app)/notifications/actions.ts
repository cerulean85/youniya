"use server";

import { refresh } from "next/cache";
import { api } from "@/lib/api";
import type { AppNotification } from "@/lib/types";

export async function readAll() {
  await api("/v1/me/notifications/read", { method: "POST", body: JSON.stringify({ all: true }) });
  refresh();
}

/** The next page of W-58, older than `before`. */
export async function loadMore(before: string) {
  return api<{ items: AppNotification[]; next_before: string | null }>(
    `/v1/me/notifications?limit=30&before=${encodeURIComponent(before)}`);
}
