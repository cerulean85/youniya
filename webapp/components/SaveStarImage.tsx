"use client";

import { useState } from "react";
import { FlashToast } from "./Offline";

export type CardData = {
  title: string; date: string; starlight: number; observation: string;
  meters: { label: string; value: number }[]; moods: { label: string; color: string }[];
};

function wrap(ctx: CanvasRenderingContext2D, text: string, width: number) {
  const lines: string[] = [];
  let line = "";
  for (const ch of text) {
    if (ctx.measureText(line + ch).width > width && line) { lines.push(line); line = ch.trimStart(); } else line += ch;
  }
  if (line) lines.push(line);
  return lines;
}

/** Any CSS colour (a var, a hex, rgb()) as "r, g, b", so it can take an alpha. */
function rgb(color: string) {
  const el = document.createElement("span");
  el.style.color = color;
  document.body.appendChild(el);
  const out = getComputedStyle(el).color.match(/[\d.]+/g)?.slice(0, 3).join(", ") ?? "139, 92, 246";
  el.remove();
  return out;
}

/** The star card (W-24) drawn on a canvas, 1080×1350, in the account's 우주의 색. */
async function draw(d: CardData) {
  await document.fonts.ready;
  const primary = `rgb(${rgb("var(--primary)")})`, primaryRgb = rgb("var(--primary)"), gold = `rgb(${rgb("var(--gold)")})`;
  const font = (family: string) => { const el = document.createElement("span"); el.style.fontFamily = family; document.body.appendChild(el); const f = getComputedStyle(el).fontFamily; el.remove(); return f; };
  const sans = font("var(--sans), sans-serif"), serif = font("var(--serif), serif");
  const W = 1080, H = 1350, s = 2;
  const c = Object.assign(document.createElement("canvas"), { width: W, height: H });
  const ctx = c.getContext("2d")!;
  ctx.fillStyle = "#0b0f19"; ctx.fillRect(0, 0, W, H);
  const glow = ctx.createRadialGradient(W * 0.8, H * 0.1, 0, W * 0.8, H * 0.1, W * 0.9);
  glow.addColorStop(0, `rgba(${primaryRgb}, 0.33)`); glow.addColorStop(1, "rgba(0, 0, 0, 0)");
  ctx.fillStyle = glow; ctx.fillRect(0, 0, W, H);
  for (let i = 0; i < 90; i++) { ctx.fillStyle = `rgba(255,255,255,${0.15 + ((i * 37) % 50) / 100})`; ctx.fillRect((i * 263) % W, (i * 491) % H, 2, 2); }
  const pad = 40 * s;
  ctx.fillStyle = "rgba(255,255,255,0.6)"; ctx.font = `400 ${13 * s}px ${sans}`;
  ctx.fillText(`오늘의 별 카드 · ${d.date}`, pad, 64 * s);
  ctx.fillStyle = gold; ctx.font = `600 ${15 * s}px ${sans}`;
  ctx.fillText(`✦ ${d.starlight} 별빛`, pad, 96 * s);
  ctx.fillStyle = "#fff"; ctx.font = `400 ${84 * s}px ${serif}`;
  ctx.fillText(String(d.starlight), pad, 200 * s);
  ctx.font = `500 ${24 * s}px ${serif}`;
  ctx.fillText(d.title, pad, 260 * s);
  ctx.fillStyle = "rgba(255,255,255,0.78)"; ctx.font = `400 ${16 * s}px ${serif}`;
  wrap(ctx, d.observation, W - pad * 2).slice(0, 4).forEach((l, i) => ctx.fillText(l, pad, (300 + i * 28) * s));
  const colors = [primary, "#22d3ee", "#ec4899"];
  d.meters.forEach((m, i) => {
    const y = (440 + i * 50) * s;
    ctx.fillStyle = "rgba(255,255,255,0.6)"; ctx.font = `400 ${13 * s}px ${sans}`; ctx.fillText(m.label, pad, y);
    ctx.fillStyle = "rgba(255,255,255,0.12)"; ctx.fillRect(pad, y + 12 * s, W - pad * 2, 6 * s);
    ctx.fillStyle = colors[i]; ctx.fillRect(pad, y + 12 * s, (W - pad * 2) * Math.max(0, Math.min(1, m.value)), 6 * s);
  });
  let x = pad;
  ctx.font = `500 ${13 * s}px ${sans}`;
  for (const m of d.moods) {
    const w = ctx.measureText(m.label).width + 40 * s;
    ctx.fillStyle = `rgba(${rgb(m.color)}, 0.2)`; ctx.beginPath(); ctx.roundRect(x, 600 * s, w, 32 * s, 16 * s); ctx.fill();
    ctx.fillStyle = m.color; ctx.beginPath(); ctx.arc(x + 14 * s, 616 * s, 4 * s, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#fff"; ctx.fillText(m.label, x + 24 * s, 621 * s);
    x += w + 8 * s;
  }
  ctx.fillStyle = "rgba(255,255,255,0.5)"; ctx.font = `500 ${12 * s}px ${sans}`;
  ctx.fillText("YOUNIYA", W - pad - ctx.measureText("YOUNIYA").width, H - 32 * s);
  return new Promise<Blob | null>((r) => c.toBlob(r, "image/png"));
}

// C-5 (Mobile 70 for one star): '이미지로 저장' downloads the star card as a PNG.
export function SaveStarImage({ card }: { card: CardData }) {
  const [toast, setToast] = useState<{ text: string; n: number } | null>(null);
  const save = async () => {
    const blob = await draw(card).catch(() => null);
    if (!blob) { setToast((t) => ({ text: "이미지를 만들지 못했어요", n: (t?.n ?? 0) + 1 })); return; }
    const url = URL.createObjectURL(blob);
    const a = Object.assign(document.createElement("a"), { href: url, download: `${card.title.replace(/[\\/:*?"<>|]/g, "").trim() || "별"}.png` });
    a.click();
    URL.revokeObjectURL(url);
    setToast((t) => ({ text: "이미지로 저장했어요", n: (t?.n ?? 0) + 1 }));
  };
  return (
    <>
      <button type="button" className="btn btn-ghost" onClick={save}>이미지로 저장</button>
      {toast && <FlashToast key={toast.n} message={toast.text} />}
    </>
  );
}
