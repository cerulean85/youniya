export function Stat({ label, value, sub, tone }: { label: string; value: string | number; sub?: string; tone?: "amber" | "red" }) {
  return (
    <div className="card stat">
      <span className="faint">{label}</span>
      <b style={tone ? { color: `var(--${tone})` } : undefined}>{value}</b>
      {sub && <span className="faint">{sub}</span>}
    </div>
  );
}
