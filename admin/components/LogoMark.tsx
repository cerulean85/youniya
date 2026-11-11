// The app icon's star as the logo mark (Figma Web/Sidebar 359:507 'Logo Mark', 2026-11-11): four points with an
// inner radius of 0.30, white into #C4B5FD from top to bottom, and a #A78BFA glow.
export function LogoMark({ size = 20 }: { size?: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden="true" style={{ flex: "none", overflow: "visible", filter: "drop-shadow(0 0 4px rgb(167 139 250 / 0.9))" }}>
      <defs>
        <linearGradient id="logo-mark" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#ffffff" />
          <stop offset="1" stopColor="#c4b5fd" />
        </linearGradient>
      </defs>
      <polygon points="50.0,4.0 59.8,40.2 96.0,50.0 59.8,59.8 50.0,96.0 40.2,59.8 4.0,50.0 40.2,40.2" fill="url(#logo-mark)" />
    </svg>
  );
}
