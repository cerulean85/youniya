export type Mood = "calm" | "sorrow" | "anger" | "insight";
export type StarState = "floated" | "kept";

export type StarSummary = {
  id: string;
  title: string;
  mood: Mood;
  /** Several moods, the first being the star's colour (기획서 17.1). `mood` stays as moods[0]. */
  moods?: Mood[];
  /** New screens decide by these, not `state` (kept for older iOS builds). A lit star is locked. */
  has_starlight?: boolean;
  locked?: boolean;
  /** The prism that read it, e.g. "prism-v1-2026-11"; null for a star without starlight. */
  prism_version?: string | null;
  state: StarState;
  created_at: string;
  updated_at: string | null;
  starlight: number | null;
  rewrite_of: string | null;
  analysis_failed: boolean;
  shared: boolean;
};

export type Analysis = {
  starlight: number;
  /** Raw measures: depth out of 400, clarity and weight out of 300 (they add up to the starlight). */
  scores?: { depth: number; clarity: number; weight: number };
  /** 별빛 풀이 (기획서 17.3): why each measure came out as it did, and an overall reading (API Dev Session, step 5). */
  depth_reason?: string | null;
  clarity_reason?: string | null;
  weight_reason?: string | null;
  interpretation?: string | null;
  tier: string;
  depth: number;
  clarity: number;
  weight: number;
  depth_level: number;
  moods: { mood: Mood; share: number }[];
  observation: string;
  telescope_teaser: string | null;
  rewrite_question: string | null;
  impact_quote: string | null;
  shape: { points: number; sharpness: string } | null;
};

export type Star = StarSummary & { body: string; analysis: Analysis | null };

export type Me = {
  id: string;
  provider: string;
  needs_consent: boolean;
  /** 별지기 이름 (기획서 15장); absent until the API ships it. */
  nickname?: string | null;
  coins: number;
  free_star_today: number;
  free_telescope: number;
};

export type Summary = {
  total: number;
  floated: number;
  kept: number;
  deep: number;
  supernova: number;
  by_month: { month: string; count: number }[];
};

export type Draft = { mood: Mood; moods?: Mood[]; title: string; body: string } | null;

export type CreateResult = { star: Star; crisis: unknown; charged: number; coins: number };

export type PlazaStar = {
  id: string; // the share id
  name: string;
  quote: string;
  mood: Mood;
  moods: Mood[];
  depth_level: number;
  shape: { points: number; sharpness: "soft" | "normal" | "sharp" | string } | null;
  created_at: string;
  resonated: boolean;
  beside: boolean;
};

export type NebulaSummary = {
  id: string; name: string; silhouette: string | null; star_count: number; depth_level: number;
  shared: boolean; created_at: string; updated_at: string | null;
};
export type NebulaStar = { id: string; index: number; title: string; mood: Mood; starlight: number; shape: PlazaStar["shape"]; depth_level: number; created_at: string };
export type Nebula = {
  id: string; name: string; silhouette: string | null; edges: number[][]; stars: NebulaStar[];
  star_count: number; depth_level: number; moods: Mood[]; guests: { share_id?: string; mood?: Mood; name?: string }[];
  shared: boolean; created_at: string; updated_at: string | null;
};
export type Growth = {
  stage: number; stage_name: string | null; floated: number; deep: number; supernova: number;
  next: { stage: number; stage_name: string; needs: Record<string, [number, number]> } | null;
  milestones: { key: string; title: string; at: string }[];
};
export type Story = {
  name: string; since: string; star_count: number;
  entries: { star_id: string; date: string; title: string; sentence: string }[];
};
export type PlazaNebula = {
  id: string; name: string; quote: string | null; moods: Mood[]; depth_level: number;
  shape: { silhouette: string | null; edges: number[][]; stars: { mood: Mood; depth_level?: number }[] };
  receive_lines: boolean; created_at: string; resonated: boolean; beside: boolean;
};
