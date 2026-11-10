import type { CSSProperties, ReactNode } from "react";
import styles from "./Skeleton.module.css";

// The pieces of the W-63~W-67 skeletons, and one skeleton per screen. Only the main area; the sidebar draws at once.
export const Bar = ({ w = "100%", h = 10, style }: { w?: number | string; h?: number; style?: CSSProperties }) =>
  <span className={styles.bar} style={{ width: w, height: h, ...style }} />;
export const Block = ({ w = "100%", h, r, style }: { w?: number | string; h: number; r?: number; style?: CSSProperties }) =>
  <span className={styles.block} style={{ width: w, height: h, borderRadius: r, ...style }} />;
export const Circle = ({ size }: { size: number }) => <span className={styles.circle} style={{ width: size, height: size }} />;

function Wrap({ label, children }: { label: string; children: ReactNode }) {
  return <div className={styles.wrap} role="status" aria-busy="true" aria-label={label}>{children}</div>;
}
/** Lines of text: the last one at 60% (W-64). */
const Lines = ({ n, h = 10, gap = 14 }: { n: number; h?: number; gap?: number }) => (
  <div className={styles.col} style={{ gap }}>{Array.from({ length: n }, (_, i) => <Bar key={i} h={h} w={i === n - 1 ? "60%" : "100%"} />)}</div>
);

/** W-63 오늘: the writing card, the month's link, recent stars. */
export function HomeSkeleton() {
  return (
    <Wrap label="오늘을 불러오는 중">
      <div className={styles.split} style={{ gridTemplateColumns: "1fr 400px" }}>
        <div className={styles.col} style={{ gap: 24 }}>
          <div className={`card ${styles.card}`} style={{ height: 230, borderRadius: 24 }}><div className={styles.row}><Bar w="45%" h={14} /><Bar w="16%" h={8} /></div><Bar w="85%" h={8} /><Bar w={240} h={40} /><Bar w="55%" h={8} /></div>
          <div className={`card ${styles.card}`} style={{ height: 56, borderRadius: 16 }}><div className={styles.row}><Bar w="55%" h={8} /><Bar w="14%" h={8} /></div></div>
        </div>
        <div className={styles.col}>
          <div className={styles.row}><Bar w="80%" h={8} /><Bar w="10%" h={8} /></div>
          {[0, 1, 2, 3, 4].map((i) => <Block key={i} h={70} r={16} />)}
        </div>
      </div>
    </Wrap>
  );
}

/** W-64 별 상세: the writing on the left, the star card and its buttons on the right. */
export function StarSkeleton() {
  return (
    <Wrap label="별을 불러오는 중">
      <div className={styles.split}>
        <div className={styles.col} style={{ gap: 20, paddingTop: 8 }}>
          <Bar w={120} h={8} />
          <Bar w="50%" h={22} />
          <Lines n={13} h={9} gap={13} />
        </div>
        <div className={styles.col} style={{ gap: 14 }}>
          <Block h={400} r={24} />
          <Bar w={84} h={8} />
          <Block h={46} />
          <Block h={46} />
          <div className={styles.grid3} style={{ gap: 10 }}>{[0, 1, 2].map((i) => <Block key={i} h={46} />)}</div>
        </div>
      </div>
    </Wrap>
  );
}

/** W-65 기록: list or calendar tabs, search, filter chips, month groups and the calendar card. */
export function RecordsSkeleton() {
  return (
    <Wrap label="기록을 불러오는 중">
      <div className={styles.col} style={{ gap: 20 }}>
        <div className={styles.row} style={{ gap: 16 }}><Block w={340} h={42} r={999} /><Block h={42} r={14} /></div>
        <div className={styles.chips}>{[64, 76, 100, 64, 64, 64, 64].map((w, i) => <Block key={i} w={w} h={32} r={10} />)}</div>
        <div className={styles.splitWide} style={{ gridTemplateColumns: "1fr 340px" }}>
          <div className={styles.col}>
            <div className={styles.row}><Bar w="90%" h={8} /><Bar w="8%" h={8} /></div>
            {[0, 1, 2, 3].map((i) => <Block key={i} h={78} r={16} />)}
            <div className={styles.row}><Bar w="90%" h={8} /><Bar w="8%" h={8} /></div>
            {[0, 1].map((i) => <Block key={i} h={78} r={16} />)}
          </div>
          <div className={`card ${styles.card}`}>
            <div className={styles.row}><Bar w="80%" /><Bar w="12%" /></div>
            <div className={styles.calDots}>{Array.from({ length: 30 }, (_, i) => <Bar key={i} w={12} h={8} />)}</div>
          </div>
        </div>
      </div>
    </Wrap>
  );
}

/** W-66 우주 광장: filter chips, shared-star rows, the 내 별 card, the rules and the button. */
export function PlazaSkeleton() {
  return (
    <Wrap label="우주 광장을 불러오는 중">
      <div className={styles.col} style={{ gap: 20 }}>
        <div className={styles.chips}>{[92, 124, 92].map((w, i) => <Block key={i} w={w} h={34} r={10} />)}</div>
        <div className={styles.split} style={{ gridTemplateColumns: "1fr 340px" }}>
          <div>
            {[0, 1, 2, 3, 4, 5].map((i) => (
              <div key={i} className={styles.listRow}>
                <Block w={40} h={40} r={10} />
                <div className={styles.col} style={{ flex: 1, gap: 8 }}><Bar /><Bar h={7} /></div>
                <Circle size={10} />
              </div>
            ))}
          </div>
          <div className={styles.col} style={{ gap: 16 }}>
            <div className={`card ${styles.card}`}>
              <Bar />{[0, 1, 2].map((i) => <div key={i} className={styles.row} style={{ justifyContent: "space-between" }}><Bar w="30%" h={7} /><Bar w={24} h={7} /></div>)}
            </div>
            <div className={`card ${styles.card}`}><Bar /><Lines n={5} h={7} gap={10} /></div>
            <Block h={48} r={14} />
          </div>
        </div>
      </div>
    </Wrap>
  );
}

/** W-67 나의 별자리: an empty canvas card (no stars or lines), three numbers, progress, links. */
export function ConstellationSkeleton() {
  return (
    <Wrap label="별자리를 불러오는 중">
      <div className={styles.split} style={{ gridTemplateColumns: "1fr 400px" }}>
        <div className={`card ${styles.card}`} style={{ height: 600 }} />
        <div className={styles.col} style={{ gap: 14 }}>
          <div className={styles.grid3} style={{ gap: 10 }}>
            {[0, 1, 2].map((i) => <div key={i} className={`card ${styles.card}`} style={{ alignItems: "center", borderRadius: 18, padding: 18 }}><Circle size={16} /><Bar w="50%" h={7} /></div>)}
          </div>
          <div className={`card ${styles.card}`} style={{ borderRadius: 18 }}>
            <div className={styles.row}><Bar w="85%" h={8} /><Bar w="10%" h={8} /></div>
            <Bar h={4} /><Lines n={2} h={7} gap={10} />
          </div>
          <Block h={46} />
          <Bar w={60} h={7} style={{ marginTop: 6 }} />
          {[0, 1].map((i) => (
            <div key={i} className={`card ${styles.card}`} style={{ flexDirection: "row", alignItems: "center", padding: 16, borderRadius: 16 }}>
              <Circle size={18} /><div className={styles.col} style={{ flex: 1, gap: 8 }}><Bar w="40%" h={8} /><Bar w="70%" h={7} /></div><Circle size={16} />
            </div>
          ))}
        </div>
      </div>
    </Wrap>
  );
}
