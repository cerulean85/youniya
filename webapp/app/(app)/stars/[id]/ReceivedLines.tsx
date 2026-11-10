import { api, ApiError } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { LINE_CHIPS, type ReceivedLine } from "@/lib/types";
import { deleteLine } from "./actions";
import { LineReport } from "./LineReport";
import styles from "./star.module.css";

// 12-4 받은 별빛 한 줄 (기획서 10.1): only the owner reads them; they stay after the star leaves the plaza.
export async function ReceivedLines({ id, shared = false }: { id: string; shared?: boolean }) {
  let data: { items: ReceivedLine[]; count: number };
  try {
    data = await api(`/v1/stars/${id}/lines`);
  } catch (e) {
    if (e instanceof ApiError && (e.status === 404 || e.status === 405)) return null;
    throw e;
  }
  // A shared star always shows the entry (iOS 12-1); none yet says so.
  if (!data.count) return shared ? (
    <section className={styles.lines} aria-label="받은 별빛 한 줄">
      <span className="label-m">받은 별빛 한 줄</span>
      <p className="caption faint">아직 받은 한 줄이 없어요.</p>
    </section>
  ) : null;
  return (
    <section className={styles.lines} aria-label="받은 별빛 한 줄">
      <span className="label-m">받은 별빛 한 줄 {data.count}</span>
      {data.items.map((l) => (
        <div key={l.id} className={styles.line}>
          <span className="body-s">{l.text ?? LINE_CHIPS.find((c) => c.key === l.chip)?.label ?? ""}</span>
          <span className={styles.lineMeta}>
            <span className="caption faint">{l.nickname ?? "별지기"} · {dateTime(l.created_at)}</span>
            <LineReport id={id} lineId={l.id} />
            <form action={deleteLine.bind(null, id, l.id)}><button>지우기</button></form>
          </span>
        </div>
      ))}
    </section>
  );
}
