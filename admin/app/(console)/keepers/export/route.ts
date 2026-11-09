import { NextResponse } from "next/server";
import { ApiError, keepersCsv } from "@/lib/api";
import { session } from "@/lib/session";

// A-05 CSV 내보내기 (owners): counts only, never writing. The API logs who exported.
export async function GET(request: Request) {
  const s = await session();
  if (!s) return NextResponse.redirect(new URL("/login", request.url));
  if (s.operator.role !== "owner") return NextResponse.redirect(new URL("/forbidden", request.url));
  try {
    const csv = await keepersCsv();
    return new NextResponse(`﻿${csv}`, {
      headers: { "Content-Type": "text/csv; charset=utf-8", "Content-Disposition": 'attachment; filename="keepers.csv"', "Cache-Control": "no-store" },
    });
  } catch (e) {
    if (e instanceof ApiError) return new NextResponse(e.message, { status: e.status });
    throw e;
  }
}
