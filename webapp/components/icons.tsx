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
export const Heart = (p: IconProps) => <svg {...base(p)}><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10Z" /></svg>;
