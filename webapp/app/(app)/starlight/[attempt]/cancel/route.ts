import { api, ApiError } from "@/lib/api";

type Cancelled = { status: "cancelled"; star: { id: string } | null; refunded: { used: string; coins: number } | null; coins: number };

// W-105 그만두기: the server drops the prism's reading (or takes back one that just finished) and charges nothing.
// Answers where to go: the star without starlight, or back to writing when the star wasn't saved yet.
export async function POST(_req: Request, { params }: RouteContext<"/starlight/[attempt]/cancel">) {
  const { attempt } = await params;
  try {
    const r = await api<Cancelled>(`/v1/starlight/attempts/${encodeURIComponent(attempt)}/cancel`, { method: "POST" });
    return Response.json({ to: r.star ? `/stars/${r.star.id}?stopped=1` : "/write?stopped=1" });
  } catch (e) {
    if (e instanceof ApiError) return Response.json({ error: e.code }, { status: e.status });
    throw e;
  }
}
