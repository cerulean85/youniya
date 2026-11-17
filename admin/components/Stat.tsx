/** One number in a `.strip` (Figma Admin v2: numbers as one strip with vertical dividers). */
export function Stat({ label, value, sub, tone }: { label: string; value: string | number; sub?: string; tone?: "amber" | "red" }) {
  return (
    <div className="strip-item">
      <span className="k">{label}</span>
      <b style={tone ? { color: `var(--${tone})` } : undefined}>{value}</b>
      {sub && <span className="s">{sub}</span>}
    </div>
  );
}
