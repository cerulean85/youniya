// 기획서 22·23장: the star card (Mobile 12-14) and the constellation card (Mobile 08-9), drawn in the browser
// at 1080×1920. Nothing is uploaded, and the writing itself never goes on a card.
import { starPoints } from "@/components/StarGlyph";
import { CANVAS } from "./constellation";

export type StarCardData = {
  date: string; month: string; title: string | null;
  shape: { points: number; sharpness: string } | null; color: string;
  starlight: number | null; moods: { label: string; color: string }[];
};
export type ConstellationCardData = {
  heading: string; name: string; filled: number; total: number; count: number;
  slots: { x: number; y: number; color: string | null; lit: boolean; starlight: number | null; shape: { points: number; sharpness: string } | null; date: string | null }[];
  lines: number[][];
};

const W = 1080, H = 1920, S = 3; // drawn on the 360×640 design, three times over

/** Any CSS colour (a var, a hex, rgb()) as "r, g, b", so it can take an alpha. */
function rgb(color: string) {
  const el = document.createElement("span");
  el.style.color = color;
  document.body.appendChild(el);
  const out = getComputedStyle(el).color.match(/[\d.]+/g)?.slice(0, 3).join(", ") ?? "139, 92, 246";
  el.remove();
  return out;
}

function family(f: string) {
  const el = document.createElement("span");
  el.style.fontFamily = f;
  document.body.appendChild(el);
  const out = getComputedStyle(el).fontFamily;
  el.remove();
  return out;
}

async function canvas() {
  await document.fonts.ready;
  const c = Object.assign(document.createElement("canvas"), { width: W, height: H });
  const ctx = c.getContext("2d")!;
  const primary = rgb("var(--primary)");
  ctx.fillStyle = "#0b0f19"; ctx.fillRect(0, 0, W, H);
  const glow = (x: number, y: number, r: number, color: string, a: number) => {
    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, `rgba(${color}, ${a})`); g.addColorStop(1, `rgba(${color}, 0)`);
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
  };
  glow(W * 0.95, H * 0.02, W * 0.75, primary, 0.28);
  glow(W * 0.85, H * 0.82, W * 0.5, "34, 211, 238", 0.08);
  for (let i = 0; i < 120; i++) {
    ctx.fillStyle = `rgba(255,255,255,${0.12 + ((i * 37) % 45) / 100})`;
    const r = i % 7 === 0 ? 2.4 : 1.4;
    ctx.beginPath(); ctx.arc((i * 263) % W, (i * 491) % H, r, 0, Math.PI * 2); ctx.fill();
  }
  return { c, ctx, sans: family("var(--sans), sans-serif"), serif: family("var(--serif), serif"), glow };
}

function centered(ctx: CanvasRenderingContext2D, text: string, y: number) {
  ctx.fillText(text, (W - ctx.measureText(text).width) / 2, y);
}

function footer(ctx: CanvasRenderingContext2D, serif: string, sans: string) {
  ctx.fillStyle = "rgba(255,255,255,0.92)"; ctx.font = `400 ${19 * S}px ${serif}`;
  ctx.letterSpacing = `${3 * S}px`; centered(ctx, "YOUNIYA", 586 * S); ctx.letterSpacing = "0px";
  ctx.fillStyle = "rgba(255,255,255,0.55)"; ctx.font = `400 ${11 * S}px ${sans}`;
  centered(ctx, "쓴 마음이 별이 되는 밤하늘 일기", 604 * S);
}

/** A star of `shape` at (cx, cy), tips at `size`, glowing in `mood` ("r, g, b"). */
function paintStar(ctx: CanvasRenderingContext2D, cx: number, cy: number, size: number, shape: { points: number; sharpness: string }, mood: string, blur: number) {
  const k = size / 46; // starPoints draws in a 100 box with tips at radius 46
  const pts = starPoints(shape.points, shape.sharpness).split(" ").map((p) => p.split(",").map(Number));
  ctx.save();
  ctx.shadowColor = `rgba(${mood}, 0.9)`; ctx.shadowBlur = blur;
  ctx.beginPath();
  pts.forEach(([x, y], i) => (i ? ctx.lineTo : ctx.moveTo).call(ctx, cx + (x - 50) * k, cy + (y - 50) * k));
  ctx.closePath();
  const fill = ctx.createRadialGradient(cx, cy, 0, cx, cy, size);
  fill.addColorStop(0, "rgba(255,255,255,0.95)"); fill.addColorStop(0.35, `rgba(${mood}, 0.95)`); fill.addColorStop(1, `rgba(${mood}, 0.75)`);
  ctx.fillStyle = fill; ctx.fill();
  ctx.shadowBlur = 0; ctx.lineJoin = "round"; ctx.lineWidth = Math.max(1, size / 40); ctx.strokeStyle = "rgba(255,255,255,0.55)"; ctx.stroke();
  ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(cx, cy, size * 0.14, 0, Math.PI * 2); ctx.fill();
  ctx.restore();
}

const blob = (c: HTMLCanvasElement) => new Promise<Blob | null>((r) => c.toBlob(r, "image/png"));

export async function drawStarCard(d: StarCardData) {
  const { c, ctx, sans, serif, glow } = await canvas();
  const mood = rgb(d.color);
  ctx.fillStyle = "rgba(255,255,255,0.55)"; ctx.font = `400 ${12 * S}px ${sans}`;
  centered(ctx, `${d.date} · ${d.month}`, 78 * S);
  if (d.title) { ctx.fillStyle = "#fff"; ctx.font = `500 ${20 * S}px ${serif}`; centered(ctx, d.title, 126 * S); }
  // The star: its own shape in its first mood's colour; a star without starlight is a small faint dot.
  const cx = W / 2, cy = 300 * S;
  glow(cx, cy, 150 * S, mood, 0.22);
  if (d.shape) {
    paintStar(ctx, cx, cy, 64 * S, d.shape, mood, 40 * S);
  } else {
    ctx.save(); ctx.shadowColor = `rgba(${mood}, 0.6)`; ctx.shadowBlur = 24 * S;
    ctx.fillStyle = `rgba(${mood}, 0.75)`; ctx.beginPath(); ctx.arc(cx, cy, 14 * S, 0, Math.PI * 2); ctx.fill(); ctx.restore();
  }
  // 별빛 badge
  const primary = rgb("var(--primary)");
  ctx.font = `600 ${14 * S}px ${sans}`;
  const label = d.starlight != null ? `✦ ${d.starlight.toLocaleString("ko-KR")} 별빛` : "별빛 없는 별";
  const bw = ctx.measureText(label).width + 36 * S, by = 430 * S, bh = 30 * S;
  ctx.fillStyle = `rgba(${primary}, 0.22)`; ctx.strokeStyle = `rgba(${primary}, 0.7)`; ctx.lineWidth = 1.2 * S;
  ctx.beginPath(); ctx.roundRect((W - bw) / 2, by, bw, bh, bh / 2); ctx.fill(); ctx.stroke();
  ctx.fillStyle = "#fff"; centered(ctx, label, by + 20 * S);
  // mood chips
  ctx.font = `500 ${13 * S}px ${sans}`;
  const chips = d.moods.slice(0, 4).map((m) => ({ ...m, w: ctx.measureText(m.label).width + 44 * S }));
  const gap = 8 * S, total = chips.reduce((n, m) => n + m.w, 0) + gap * Math.max(0, chips.length - 1);
  let x = (W - total) / 2;
  const cyChip = 473 * S, ch = 32 * S;
  for (const m of chips) {
    const col = rgb(m.color);
    ctx.fillStyle = `rgba(${col}, 0.16)`; ctx.strokeStyle = `rgba(${col}, 0.7)`;
    ctx.beginPath(); ctx.roundRect(x, cyChip, m.w, ch, ch / 2); ctx.fill(); ctx.stroke();
    ctx.fillStyle = `rgb(${col})`; ctx.beginPath(); ctx.arc(x + 16 * S, cyChip + ch / 2, 4 * S, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#fff"; ctx.fillText(m.label, x + 26 * S, cyChip + 21 * S);
    x += m.w + gap;
  }
  footer(ctx, serif, sans);
  return blob(c);
}

export async function drawConstellationCard(d: ConstellationCardData) {
  const { c, ctx, sans, serif, glow } = await canvas();
  ctx.fillStyle = "rgba(255,255,255,0.55)"; ctx.font = `400 ${12 * S}px ${sans}`;
  centered(ctx, d.heading, 78 * S);
  // Mobile 08-9 (2026-11-10): the figure nearly card-wide, each filled slot drawn as that star's shape with its date.
  const bw = 320 * S, bh = bw * (CANVAS.height / CANVAS.width), x0 = (W - bw) / 2, y0 = 100 * S;
  const at = (i: number) => [x0 + d.slots[i].x * bw, y0 + d.slots[i].y * bh] as const;
  for (const [a, b] of d.lines) {
    const lit = !!(d.slots[a]?.color && d.slots[b]?.color);
    const [x1, y1] = at(a), [x2, y2] = at(b);
    ctx.strokeStyle = lit ? "rgba(251,191,36,0.55)" : "rgba(255,255,255,0.18)"; ctx.lineWidth = 1.2 * S;
    ctx.setLineDash(lit ? [] : [3 * S, 6 * S]);
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  }
  ctx.setLineDash([]);
  d.slots.forEach((s, i) => {
    const [x, y] = at(i);
    if (!s.color) {
      ctx.strokeStyle = "rgba(255,255,255,0.4)"; ctx.lineWidth = S; ctx.setLineDash([3 * S, 3 * S]);
      ctx.beginPath(); ctx.arc(x, y, 5 * S, 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
      return;
    }
    const col = rgb(s.color);
    glow(x, y, 46 * S, col, 0.16);
    if (s.lit && s.shape) paintStar(ctx, x, y, (17 + ((s.starlight ?? 300) / 1000) * 6) * S, s.shape, col, 16 * S);
    else {
      ctx.save(); if (s.lit) { ctx.shadowColor = `rgba(${col}, 0.9)`; ctx.shadowBlur = 14 * S; }
      ctx.fillStyle = `rgba(${col}, ${s.lit ? 1 : 0.6})`; ctx.beginPath(); ctx.arc(x, y, (s.lit ? 9 : 6) * S, 0, Math.PI * 2); ctx.fill(); ctx.restore();
    }
    if (s.date) { ctx.fillStyle = "rgba(255,255,255,0.45)"; ctx.font = `400 ${11 * S}px ${sans}`; ctx.fillText(s.date, x - ctx.measureText(s.date).width / 2, y + 36 * S); }
  });
  ctx.fillStyle = "#fff"; ctx.font = `400 ${30 * S}px ${serif}`;
  centered(ctx, `${d.name}자리`, 448 * S);
  ctx.fillStyle = "rgba(255,255,255,0.6)"; ctx.font = `400 ${13 * S}px ${sans}`;
  centered(ctx, d.filled >= d.total ? `${d.total}자리를 모두 채웠어요 · 별 ${d.count}개` : `${d.total}자리 중 ${d.filled}자리를 채웠어요 · 별 ${d.count}개`, 482 * S);
  const pw = 200 * S, px = (W - pw) / 2, py = 497 * S, ph = 4 * S;
  ctx.fillStyle = "rgba(255,255,255,0.14)"; ctx.beginPath(); ctx.roundRect(px, py, pw, ph, ph / 2); ctx.fill();
  ctx.fillStyle = `rgb(${rgb("var(--gold)")})`; ctx.beginPath(); ctx.roundRect(px, py, pw * Math.min(1, d.filled / Math.max(1, d.total)), ph, ph / 2); ctx.fill();
  footer(ctx, serif, sans);
  return blob(c);
}
