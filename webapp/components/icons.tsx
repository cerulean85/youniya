import type { SVGProps } from "react";

// Line icons matching the Figma Icon/* set: 24×24, 1.6 stroke, coloured with currentColor.
type IconProps = SVGProps<SVGSVGElement> & { size?: number };

function base({ size = 20, ...rest }: IconProps) {
  return {
    width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
    strokeWidth: 1.6, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, "aria-hidden": true, ...rest,
  };
}

const STAR = "M12 2c.8 6.5 3.5 9.2 10 10-6.5.8-9.2 3.5-10 10-.8-6.5-3.5-9.2-10-10 6.5-.8 9.2-3.5 10-10Z";

export const Star = (p: IconProps) => <svg {...base(p)}><path d={STAR} /></svg>;
export const StarFilled = (p: IconProps) => <svg {...base(p)} fill="currentColor" stroke="none"><path d={STAR} /></svg>;
export const Moon = (p: IconProps) => <svg {...base(p)}><path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5Z" /></svg>;
export const Nebula = (p: IconProps) => <svg {...base(p)}><path d="M7 18h10a4 4 0 0 0 .5-8A6 6 0 0 0 6 9.5 4.3 4.3 0 0 0 7 18Z" /></svg>;
export const Archive = (p: IconProps) => <svg {...base(p)}><rect x="3.5" y="4.5" width="17" height="5" rx="1.5" /><path d="M5 9.5V18a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9.5M10 13h4" /></svg>;
export const Telescope = (p: IconProps) => <svg {...base(p)}><path d="m3 13 3 3 12-7-2-4L4 11Z" /><path d="m11 13 2 7M13 12l3 8" /></svg>;
export const Coin = (p: IconProps) => <svg {...base(p)}><circle cx="12" cy="12" r="8.5" /><circle cx="12" cy="12" r="4.5" /></svg>;
export const Settings = (p: IconProps) => <svg {...base(p)}><path d="M4 7h10M18 7h2M4 17h2M10 17h10" /><circle cx="16" cy="7" r="2" /><circle cx="8" cy="17" r="2" /></svg>;
export const Mail = (p: IconProps) => <svg {...base(p)}><rect x="3" y="5" width="18" height="14" rx="2" /><path d="m4 7 8 6 8-6" /></svg>;
export const Pen = (p: IconProps) => <svg {...base(p)}><path d="M4 20l4-1 11-11-3-3L5 16l-1 4Z" /><path d="M14 6l3 3" /></svg>;
export const ChevronRight = (p: IconProps) => <svg {...base(p)}><path d="m9 18 6-6-6-6" /></svg>;
export const ChevronLeft = (p: IconProps) => <svg {...base(p)}><path d="m15 18-6-6 6-6" /></svg>;
export const Close = (p: IconProps) => <svg {...base(p)}><path d="M6 6l12 12M18 6 6 18" /></svg>;
export const Lock = (p: IconProps) => <svg {...base(p)}><rect x="5" y="10.5" width="14" height="9.5" rx="2.5" /><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" /></svg>;
export const Check = (p: IconProps) => <svg {...base(p)} strokeWidth={2}><path d="m5 12.5 4.5 4.5L19 7.5" /></svg>;
export const Info = (p: IconProps) => <svg {...base(p)}><circle cx="12" cy="12" r="9" /><path d="M12 11v5M12 8h.01" /></svg>;
export const Bell = (p: IconProps) => <svg {...base(p)}><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15L6 16Z" /><path d="M10 20a2 2 0 0 0 4 0" /></svg>;
export const Heart = (p: IconProps) => <svg {...base(p)}><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10Z" /></svg>;
export const Upload = (p: IconProps) => <svg {...base(p)}><path d="M12 15V4M7.5 8.5 12 4l4.5 4.5M5 15v3a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-3" /></svg>;
export const Trash = (p: IconProps) => <svg {...base(p)}><path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 12.5a1.5 1.5 0 0 0 1.5 1.5h6a1.5 1.5 0 0 0 1.5-1.5L17.5 7" /></svg>;
export const Phone = (p: IconProps) => <svg {...base(p)}><path d="M5 4h3.5l1.5 4-2 1.5a10 10 0 0 0 6.5 6.5l1.5-2 4 1.5V19a1.5 1.5 0 0 1-1.5 1.5A15.5 15.5 0 0 1 3.5 5.5 1.5 1.5 0 0 1 5 4Z" /></svg>;
export const Doc = (p: IconProps) => <svg {...base(p)}><path d="M6 3.5h8l4 4V20a.5.5 0 0 1-.5.5h-11A.5.5 0 0 1 6 20V3.5Z" /><path d="M14 3.5V8h4M9 12.5h6M9 16h6" /></svg>;
export const LogOut = (p: IconProps) => <svg {...base(p)}><path d="M10 4.5H6a1.5 1.5 0 0 0-1.5 1.5v12A1.5 1.5 0 0 0 6 19.5h4M15 8l4 4-4 4M19 12H9.5" /></svg>;
export const Sparkle = (p: IconProps) => <svg {...base(p)}><path d={STAR} transform="translate(3 3) scale(.75)" /></svg>;
export const Shield = (p: IconProps) => <svg {...base(p)}><path d="M12 3.5 5 6v5.5c0 4.2 3 7.6 7 9 4-1.4 7-4.8 7-9V6l-7-2.5Z" /></svg>;
export const User = (p: IconProps) => <svg {...base(p)}><circle cx="12" cy="8.5" r="3.5" /><path d="M5 20a7 7 0 0 1 14 0" /></svg>;
export const Search = (p: IconProps) => <svg {...base(p)}><circle cx="11" cy="11" r="6.5" /><path d="m20 20-4.2-4.2" /></svg>;
export const WifiOff = (p: IconProps) => <svg {...base(p)}><path d="M3 3l18 18M8.5 16.5a5 5 0 0 1 7 0M5 13a10 10 0 0 1 5-2.7M14.5 10.4A10 10 0 0 1 19 13M2 9.5a15 15 0 0 1 4.5-2.8M11 5.6a15 15 0 0 1 11 3.9" /><circle cx="12" cy="20" r=".5" fill="currentColor" /></svg>;
export const Warn = (p: IconProps) => <svg {...base(p)}><path d="M12 4 21 19.5H3L12 4Z" /><path d="M12 10v4.5M12 17h.01" /></svg>;
