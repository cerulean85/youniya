import { api, ApiError } from "@/lib/api";

// W-105 그만두기: tells the server to stop reading this star, which then stays without starlight and charges nothing.
// TODO(API contract): the endpoint name is a placeholder until the API session confirms it.
export async function POST(_req: Request, { params }: RouteContext<"/stars/[id]/stop">) {
  const { id } = await params;
  try {
    await api(`/v1/stars/${id}/starlight/cancel`, { method: "POST" });
  } catch (e) {
    if (e instanceof ApiError) return Response.json({ error: e.code }, { status: e.status });
    throw e;
  }
  return new Response(null, { status: 204 });
}
