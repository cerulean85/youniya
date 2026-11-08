export type Mood = "calm" | "sorrow" | "anger" | "insight";
export type StarState = "floated" | "kept";

export type StarSummary = {
  id: string;
  title: string;
  mood: Mood;
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
  coins: number;
  free_star_today: number;
  free_telescope: number;
  free_story: number;
};

export type Summary = {
  total: number;
  floated: number;
  kept: number;
  deep: number;
  supernova: number;
  by_month: { month: string; count: number }[];
};

export type Draft = { mood: Mood; title: string; body: string } | null;

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
