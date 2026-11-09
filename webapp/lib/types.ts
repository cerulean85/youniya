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

/** A star joined by 별 잇기 (기획서 16장): shown as 이어진 별 chips, both ways. */
export type LinkedStar = { id: string; title: string; mood: Mood; moods?: Mood[]; created_at: string; has_starlight: boolean };

/** `linked_stars` comes with the 별 잇기 API (dev server 2026-11-09); absent on older servers. */
export type Star = StarSummary & {
  body: string; analysis: Analysis | null; linked_stars?: LinkedStar[]; line_count?: number;
  /** The latest 마음 망원경 result of this star alone (API 5단계); null if none. */
  telescope?: { id: string; created_at: string; report: TelescopeResult } | null;
};

/** 마음 망원경 result. For one star (`Star.telescope`) each lens carries the prism's score and reason. */
export type FogKind = "step_back" | "unnamed" | "blaming" | "self_blame" | "overgeneral";
export type TelescopeResult = {
  star_name: string;
  lenses: { key: string; label: string; value: number; note: string; score?: number | null; reason?: string | null }[];
  emotions: { mood: Mood; label: string; percent: number }[];
  evidence: string | null;
  question: string | null;
  signals: { star_id: string; sentence: string }[];
  fog_items?: { kind: FogKind; label: string; sentence: string; note: string }[];
  mood_flow?: { start: Mood; middle: Mood; end: Mood } | null;
  mood_interpretation?: string;
};
export type TelescopeReport = { id: string; title: string; created_at: string; saved: boolean; star_ids: string[]; report: TelescopeResult };
export type TelescopeOffer = { free: boolean; free_left: number; cost: number; coins: number; enough: boolean };

export type Me = {
  id: string;
  provider: string;
  needs_consent: boolean;
  /** 별지기 이름 (기획서 15장); absent until the API ships it. */
  nickname?: string | null;
  /** When the nickname can change again (30 days after the last change). */
  nickname_next_change?: string | null;
  /** Operator actions (기획서 18장): plaza use paused until then, or a new name asked for (no 30-day wait). */
  plaza_restricted_until?: string | null;
  nickname_rename_required?: boolean;
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

/** `source_star_id`: the star a 고쳐 쓰기 draft rewrites (one draft per person). */
export type Draft = { mood: Mood; moods?: Mood[]; title: string; body: string; source_star_id?: string | null } | null;

export type CreateResult = { star: Star; crisis: unknown; charged: number; coins: number };

export type PlazaStar = {
  id: string; // the share id
  /** The writer's own title (기획서 15.2); AI names ending in 별 show only in the telescope. */
  name: string;
  /** 별지기 이름 (기획서 15장). */
  nickname: string | null;
  /** 대표 문장, masked. */
  quote: string;
  mood: Mood;
  moods: Mood[];
  depth_level: number;
  shape: { points: number; sharpness: "soft" | "normal" | "sharp" | string } | null;
  created_at: string;
  full_text: boolean;
  has_starlight: boolean;
  /** 별빛 한 줄: whether the owner takes them, and whether I already left mine. */
  receive_lines: boolean;
  line_left: boolean;
  resonated: boolean;
  beside: boolean;
  /** Detail only, when the whole writing is shared (contacts masked). */
  title_masked?: string;
  body_masked?: string;
};

export type Keeper = { nickname: string; mine: boolean; items: PlazaStar[] };
export type MyShare = { id: string; star_id: string; name: string; title: string; starlight: number | null; created_at: string; receive_lines?: boolean; lines?: number };
export type ReceivedLine = { id: string; text: string | null; chip: LineChip | null; nickname: string | null; created_at: string };
export type LineChip = "empathize" | "me_too" | "thanks";
export const LINE_CHIPS: { key: LineChip; label: string }[] = [
  { key: "empathize", label: "공감해요" }, { key: "me_too", label: "저도 그랬어요" }, { key: "thanks", label: "고마워요" },
];

export type Growth = {
  stage: number; stage_name: string | null; floated: number; deep: number; supernova: number;
  next: { stage: number; stage_name: string; needs: Record<string, [number, number]> } | null;
  milestones: { key: string; title: string; at: string }[];
};
export type Story = {
  name: string; since: string; star_count: number;
  entries: { star_id: string; date: string; title: string; sentence: string }[];
};

/** 알림함 (Mobile 130): operator actions, notices and results, kept 90 days. */
export type NotificationTarget = { screen: string; star_id?: string; notice_id?: string; until?: string };
export type AppNotification = { id: string; kind: string; title: string; body: string; target: NotificationTarget | null; created_at: string; read: boolean };
export type Notice = { id: string; title: string; body: string; published_at: string };

/** GET /v1/coins: the balance, what's free today, and the packages on sale (the same as iOS). */
export type CoinsInfo = {
  coins: number; free_star_today: number; free_telescope: number; free_telescope_available?: boolean;
  prices: { star: number; telescope: number };
  packages: { product_id: string; coins: number; price: number; bonus: number }[];
};
export type CoinEntryRow = { id: string; kind: "purchase" | "spend" | "refund" | "grant" | string; title: string; delta: number; created_at: string; source?: string | null };
