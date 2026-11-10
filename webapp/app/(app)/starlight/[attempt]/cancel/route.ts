import { api, ApiError } from "@/lib/api";

type Cancelled = { status: "cancelled"; star: { id: string } | null; refunded: { used: string; coins: number } | null; coins: number };

// W-105 그만두기: the server drops the prism's reading (or takes back one that just finished) and charges nothing.
// Answers the star, or null while the request hasn't reached the server yet (asked again until it has).
// ?draft=1 (writing a new star): the draft became that star, so it goes.
export async function POST(req: Request, { params }: RouteContext<"/starlight/[attempt]/cancel">) {
  const { attempt } = await params;
  try {
    const r = await api<Cancelled>(`/v1/starlight/attempts/${encodeURIComponent(attempt)}/cancel`, { method: "POST" });
    if (r.star && new URL(req.url).searchParams.get("draft") === "1") await api("/v1/drafts/current", { method: "DELETE" }).catch(() => null);
    return Response.json({ star_id: r.star?.id ?? null });
  } catch (e) {
    if (e instanceof ApiError) return Response.json({ error: e.code }, { status: e.status });
    throw e;
  }
}
