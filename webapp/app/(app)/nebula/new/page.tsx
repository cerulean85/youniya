import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { ChevronLeft } from "@/components/icons";
import { api } from "@/lib/api";
import type { StarSummary } from "@/lib/types";
import { DrawNebula } from "./DrawNebula";

export const metadata: Metadata = { title: "성운 그리기" };

type Guest = { share_id: string; name: string; mood: StarSummary["mood"] };

// Figma W-27 (52 별 고르기), 84 실루엣 고르기, 85 손님별, 54 이름 짓기.
export default function NewNebulaPage() {
  return (
    <>
      <Link href="/nebula" style={{ display: "inline-flex", alignItems: "center", gap: 6, color: "var(--text-2)", font: "500 14px/20px var(--sans)", marginBottom: -8 }}>
        <ChevronLeft size={18} />성운
      </Link>
      <Suspense fallback={<div className="card" style={{ minHeight: 560, opacity: 0.5 }} aria-busy="true" />}>
        <Load />
      </Suspense>
    </>
  );
}

async function Load() {
  const [stars, guests] = await Promise.all([
    api<{ items: StarSummary[] }>("/v1/stars?state=floated&limit=200"),
    api<{ items: Guest[]; max: number }>("/v1/nebulae/guest-candidates"),
  ]);
  return <DrawNebula stars={stars.items} guests={guests.items} />;
}
