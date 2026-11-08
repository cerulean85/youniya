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
