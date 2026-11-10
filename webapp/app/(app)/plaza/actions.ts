"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

/** W-76 둘러보기: the first-visit guide shows until this is pressed once (per browser, like iOS per device). */
export async function seenWelcome() {
  (await cookies()).set("yn_plaza_seen", "1", { path: "/", maxAge: 60 * 60 * 24 * 365 * 2, sameSite: "lax", httpOnly: true, secure: process.env.NODE_ENV === "production" });
  redirect("/plaza");
}
