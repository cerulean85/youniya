import styles from "./NebulaGlow.module.css";

// iOS NebulaGlowBackground (ConstellationView canvas): the sky's three glows, a over the middle, b low left,
// c high right, and 46 specks of star dust. Same seed every time, so it never shifts between renders.
const DUST = Array.from({ length: 46 }, (_, i) => {
  const r = (n: number) => { const x = Math.sin((i + 1) * 12.9898 + n * 78.233) * 43758.5453; return x - Math.floor(x); };
  return { x: +(r(1) * 100).toFixed(2), y: +(r(2) * 100).toFixed(2), s: +(1 + r(3) * 1.2).toFixed(2), a: +(0.2 + r(4) * 0.5).toFixed(2) };
});

export function NebulaGlow() {
  return (
    <div className={styles.glow} aria-hidden="true">
      {DUST.map((d, i) => <i key={i} style={{ left: `${d.x}%`, top: `${d.y}%`, width: d.s, height: d.s, opacity: d.a }} />)}
    </div>
  );
}
