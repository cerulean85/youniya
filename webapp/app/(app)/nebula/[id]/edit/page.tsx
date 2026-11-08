import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
import { api, ApiError } from "@/lib/api";
import type { Nebula, StarSummary, Story } from "@/lib/types";
import { DrawNebula } from "../../new/DrawNebula";

export const metadata: Metadata = { title: "성운 모양 바꾸기" };

type Guest = { share_id: string; name: string; mood: StarSummary["mood"] };

// Figma W-43 (성운 모양 바꾸기): shape, then stars, then name, opened with the nebula as it is.
export default function EditNebulaPage({ params }: PageProps<"/nebula/[id]/edit">) {
  return (
    <Suspense fallback={<div className="card" style={{ minHeight: 560, opacity: 0.5 }} aria-busy="true" />}>
      <Load params={params} />
    </Suspense>
  );
}

async function Load({ params }: Pick<PageProps<"/nebula/[id]/edit">, "params">) {
  const { id } = await params;
  let n: Nebula, story: Story;
  try {
    [n, story] = await Promise.all([api<Nebula>(`/v1/nebulae/${id}`), api<Story>(`/v1/nebulae/${id}/story`)]);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  const [stars, candidates] = await Promise.all([
    api<{ items: StarSummary[] }>("/v1/stars?state=floated&limit=200"),
    api<{ items: Guest[] }>("/v1/nebulae/guest-candidates"),
  ]);
  // Guests already in the nebula stay offered even if they are no longer candidates.
  const guests = [...candidates.items, ...n.guests.filter((g) => g.share_id && !candidates.items.some((c) => c.share_id === g.share_id))
    .map((g) => ({ share_id: g.share_id!, name: g.name ?? "손님별", mood: g.mood ?? "calm" }))];
  return (
    <>
      <Link href={`/nebula/${id}`} style={{ display: "inline-flex", alignItems: "center", gap: 6, color: "var(--text-2)", font: "500 14px/20px var(--sans)", marginBottom: -8 }}>
        <ChevronLeft size={18} />{n.name}
      </Link>
      <DrawNebula stars={stars.items} guests={guests} editing={{
        id, name: n.name, silhouette: n.silhouette, shared: n.shared, polished: story.polished,
        starIds: [...n.stars].sort((a, b) => a.index - b.index).map((s) => s.id),
        guestIds: n.guests.map((g) => g.share_id!).filter(Boolean),
      }} />
    </>
  );
}
