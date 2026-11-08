"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/lib/api";

export type NebulaInput = { name: string; silhouette: string | null; star_ids: string[]; edges: number[][]; guest_share_ids: string[] };

export async function createNebula(input: NebulaInput): Promise<{ error: string } | void> {
  let id: string;
  try {
    ({ id } = await api<{ id: string }>("/v1/nebulae", { method: "POST", body: JSON.stringify(input) }));
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message };
    throw e;
  }
  refresh();
  redirect(`/nebula/${id}?new=1`);
}

/** 71 하늘에 띄우기: shape, colours, depth and name go out; never the writing or dates. */
export async function shareNebula(id: string, form: FormData) {
  await api(`/v1/nebulae/${id}/share`, { method: "PUT", body: JSON.stringify({ receive_lines: form.get("receive_lines") === "on" }) });
  refresh();
}

export async function unshareNebula(id: string) {
  await api(`/v1/nebulae/${id}/share`, { method: "DELETE" });
  refresh();
}

/** 성운 다시 그리기 (W-43). A shared nebula changes in the plaza too. */
export async function editNebula(id: string, input: NebulaInput): Promise<{ error: string } | void> {
  let r: { plaza_updated: boolean };
  try {
    r = await api<{ plaza_updated: boolean }>(`/v1/nebulae/${id}`, { method: "PATCH", body: JSON.stringify(input) });
  } catch (e) {
    if (e instanceof ApiError) return { error: e.message };
    throw e;
  }
  refresh();
  redirect(`/nebula/${id}?changed=1${r.plaza_updated ? "&plaza=1" : ""}`);
}
