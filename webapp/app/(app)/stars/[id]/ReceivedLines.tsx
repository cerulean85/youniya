import { api, ApiError } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { LINE_CHIPS, type ReceivedLine } from "@/lib/types";
import { deleteLine, reportLine } from "./actions";
import styles from "./star.module.css";

// 12-4 받은 별빛 한 줄 (기획서 10.1): only the owner reads them; they stay after the star leaves the plaza.
export async function ReceivedLines({ id }: { id: string }) {
  let data: { items: ReceivedLine[]; count: number };
  try {
    data = await api(`/v1/stars/${id}/lines`);
  } catch (e) {
    if (e instanceof ApiError && (e.status === 404 || e.status === 405)) return null;
    throw e;
  }
  if (!data.count) return null;
  return (
    <section className={styles.lines} aria-label="받은 별빛 한 줄">
      <span className="label-m">받은 별빛 한 줄 {data.count}</span>
      {data.items.map((l) => (
        <div key={l.id} className={styles.line}>
          <span className="body-s">{l.text ?? LINE_CHIPS.find((c) => c.key === l.chip)?.label ?? ""}</span>
          <span className={styles.lineMeta}>
            <span className="caption faint">{l.nickname ?? "별지기"} · {dateTime(l.created_at)}</span>
            <form action={reportLine.bind(null, id, l.id)}><input type="hidden" name="reason" value="hurtful" /><button>신고</button></form>
            <form action={deleteLine.bind(null, id, l.id)}><button>지우기</button></form>
          </span>
        </div>
      ))}
    </section>
  );
}
