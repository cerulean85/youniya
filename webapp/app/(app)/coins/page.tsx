import type { Metadata } from "next";
import { connection } from "next/server";
import Link from "next/link";
import { Suspense } from "react";
import { PageHeader } from "@/components/Page";
import { api } from "@/lib/api";
import { SITE_URL } from "@/lib/config";
import type { CoinEntryRow, CoinsInfo } from "@/lib/types";
import { Recharge } from "./Recharge";
import styles from "./coins.module.css";

export const metadata: Metadata = { title: "코인" };

const day = (iso: string) => new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", month: "long", day: "numeric" }).format(new Date(iso));

// Figma W-18 (Web 시안 v2 597:30548): 충전하기 (Toss on the web), what's still free, and the last 30 days of coins.
export default function CoinsPage({ searchParams }: PageProps<"/coins">) {
  return (
    <div className="page-column" style={{ ["--column" as string]: "720px", gap: 28 }}>
      <Suspense fallback={<><PageHeader title="코인" /><div className={styles.loading} aria-busy="true" /></>}>
        <Coins searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

async function Coins({ searchParams }: Pick<PageProps<"/coins">, "searchParams">) {
  const sp = await searchParams;
  const [info, history, toss] = await Promise.all([
    api<CoinsInfo>("/v1/coins"), api<{ items: CoinEntryRow[] }>("/v1/coins/history"),
    // Web payments: available is false when the server has no Toss secret key (older servers: no endpoint).
    api<{ items: { id: string; coins: number; bonus: number; price: number }[]; available: boolean }>("/v1/payments/toss/packages").catch(() => null),
  ]);
  const packages = toss?.items.map((p) => ({ product_id: p.id, coins: p.coins, price: p.price, bonus: p.bonus })) ?? info.packages;
  await connection();
  // 전체 보기: the API sends every entry; the page shows the last 30 days unless asked for all of them.
  const all = sp.history === "all";
  const recent = all ? history.items : lastDays(history.items, 30);
  const charged = typeof sp.charged === "string" ? Number(sp.charged) : null;
  // Figma Web 시안 v2 · 코인 (597:30548): one 720px column; the balance in gold is the only large thing.
  return (
    <>
      <PageHeader title="코인" />
      {charged != null && charged > 0 && <p className={styles.notice} role="status">{charged.toLocaleString("ko-KR")} 코인을 충전했어요.</p>}
      <section className={styles.balanceV2} aria-label="보유 코인">
        <p><b>{info.coins.toLocaleString("ko-KR")}</b><span>코인 · 별빛 받기 {Math.floor(info.coins / info.prices.star)}번</span></p>
        <p className="v2-meta">별빛 받기는 하루 한 번 무료예요{info.free_star_today > 0 ? ` (오늘 ${info.free_star_today}번 남았어요)` : ""}. 그 이상은 {info.prices.star}코인이에요. 기록은 코인 없이도 쓸 수 있어요.</p>
      </section>
      <Recharge packages={packages} available={Boolean(toss?.available)} site={SITE_URL} from={typeof sp.from === "string" && sp.from.startsWith("/") && !sp.from.startsWith("//") ? sp.from : null} />
      <section className={styles.history} aria-labelledby="history-title">
        <div className={styles.historyHead}><h2 id="history-title" className="v2-group">{all ? "모든 사용 내역" : "최근 사용 내역"}</h2>{all ? <Link href="/coins" scroll={false} className="v2-link">최근 30일만 보기</Link>
          : history.items.length > recent.length ? <Link href="/coins?history=all" scroll={false} className="v2-link">전체 보기 ›</Link>
          : <span className="v2-small">최근 30일</span>}</div>
        {recent.length === 0 ? <p className="v2-meta">{all ? "아직 코인을 쓰거나 충전한 기록이 없어요." : "최근 30일 동안 코인을 쓰거나 충전한 기록이 없어요."}</p> : (
          <ul>
            {recent.map((x) => {
              const plus = x.delta > 0, free = x.delta === 0;
              return (
                <li key={x.id}>
                  <span className={styles.what}><span>{x.title}{(x.source === "toss" || x.source === "app_store") && <span className="v2-small"> · {x.source === "toss" ? "웹 결제" : "App Store"}</span>}</span><span className="v2-small">{day(x.created_at)}</span></span>
                  <span className={styles.delta} data-tone={free ? "free" : plus ? "plus" : undefined}>{free ? "무료" : plus ? `+${x.delta.toLocaleString("ko-KR")}` : `−${(-x.delta).toLocaleString("ko-KR")}`}</span>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </>
  );
}

/** The entries from the last `n` days, from one reading of the clock. */
function lastDays(items: CoinEntryRow[], n: number) {
  const since = Date.now() - n * 86400000;
  return items.filter((x) => new Date(x.created_at).getTime() >= since);
}
