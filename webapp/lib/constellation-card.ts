import type { ConstellationCardData } from "./card-image";
import type { Constellation } from "./constellation";
import { kst, moodOf } from "./format";

/** Mobile 08-9 (기획서 23장): the card for a completed month. */
export function constellationCard(c: Constellation, shapeOf: Map<string, { points: number; sharpness: string } | null> = new Map()): ConstellationCardData {
  return {
    heading: `${c.month.slice(0, 4)}년 ${Number(c.month.slice(5))}월 · 별자리 완성`, name: c.name, filled: c.filled, total: c.total, count: c.filled,
    lines: c.lines,
    slots: c.slots.map((x) => ({
      x: x.x, y: x.y, color: x.star ? moodOf(x.star.mood).color : null,
      lit: !!x.star && x.star.has_starlight !== false && x.star.starlight != null, starlight: x.star?.starlight ?? null,
      shape: x.star ? (x.star.shape !== undefined ? x.star.shape : shapeOf.get(x.star.id) ?? null) : null,
      date: x.star ? `${kst(x.star.created_at).m}/${kst(x.star.created_at).d}` : null,
    })),
  };
}
