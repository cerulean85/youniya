"use server";

import { redirect } from "next/navigation";
import { api } from "@/lib/api";

export async function agree(formData: FormData) {
  const required = ["terms", "privacy", "sensitive"].every((k) => formData.get(k) === "on");
  if (!required) redirect("/welcome?missing=1");
  await api("/v1/me/consent", {
    method: "POST",
    body: JSON.stringify({ terms: true, privacy: true, sensitive: true, marketing: formData.get("marketing") === "on" }),
  });
  redirect("/nickname"); // 기획서 15.1: the name comes right after consent
}
