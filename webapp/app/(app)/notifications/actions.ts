"use server";

import { refresh } from "next/cache";
import { api } from "@/lib/api";

export async function readAll() {
  await api("/v1/me/notifications/read", { method: "POST", body: JSON.stringify({ all: true }) });
  refresh();
}
