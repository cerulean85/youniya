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

/** Where a purchase or refund was paid (the server's own entries have no label). */
const PAID: Record<string, string> = { toss: "웹 결제", app_store: "App Store", google_play: "Google Play" };
const day = (iso: string) => new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", month: "long", day: "numeric" }).format(new Date(iso));

// Figma W-18 (Web 시안 v2 597:30548): 충전하기 (Toss on the web), what's still free, and the last 30 days of coins.
export default function CoinsPage({ searchParams }: PageProps<"/coins">) {
  return (
    <Suspense fallback={<><PageHeader title="코인" /><div className={styles.loading} aria-busy="true" /></>}>
      <Coins searchParams={searchParams} />
    </Suspense>
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
  // Figma 웹 v1.1 · 코인 (642:31448): the balance and 충전하기 on the left, the history beside it.
  return (
    <div className={styles.page}>
      <div className={styles.main}>
        <PageHeader title="코인" />
        {charged != null && charged > 0 && <p className={styles.notice} role="status">{charged.toLocaleString("ko-KR")} 코인을 충전했어요.</p>}
        <section className={styles.balance} aria-label="보유 코인">
          <p><b>{info.coins.toLocaleString("ko-KR")}</b><span>코인</span></p>
          <p className="body-s muted">
            별빛 받기 {Math.floor(info.coins / info.prices.star).toLocaleString("ko-KR")}번을 할 수 있어요 (1번에 {info.prices.star}코인)
            {info.free_star_today > 0 ? ` · 오늘 무료 별빛 ${info.free_star_today}번 남았어요` : " · 오늘 무료 별빛은 썼어요"}
          </p>
        </section>
        <Recharge packages={packages} available={Boolean(toss?.available)} site={SITE_URL} from={typeof sp.from === "string" && sp.from.startsWith("/") && !sp.from.startsWith("//") ? sp.from : null} />
      </div>
      <section className={styles.history} aria-labelledby="history-title">
        <div className={styles.historyHead}>
          <h2 id="history-title" className="h3">{all ? "모든 사용 내역" : "사용 내역 · 최근 30일"}</h2>
          {all ? <Link href="/coins" scroll={false} className={styles.historyLink}>최근 30일만 보기</Link>
            : history.items.length > recent.length && <Link href="/coins?history=all" scroll={false} className={styles.historyLink}>전체 보기 ›</Link>}
        </div>
        {recent.length === 0 ? (
          <p className={`body-s muted ${styles.historyEmpty}`}>{all ? "아직 코인을 쓰거나 충전한 기록이 없어요." : "최근 30일 동안 코인을 쓰거나 충전한 기록이 없어요."} 별빛 없이 띄우기와 하루 한 번 별빛 받기는 코인 없이 할 수 있어요.</p>
        ) : (
          <ul>
            {recent.map((x) => {
              const plus = x.delta > 0, free = x.delta === 0;
              return (
                <li key={x.id}>
                  <span className={styles.what}>
                    <span className="label-m">{x.title}</span>
                    <span className="caption faint">{[x.source && PAID[x.source], day(x.created_at)].filter(Boolean).join(" · ")}</span>
                  </span>
                  <span className={styles.delta} data-tone={free ? "free" : plus ? "plus" : undefined}>{free ? "무료" : plus ? `+${x.delta.toLocaleString("ko-KR")}` : `−${(-x.delta).toLocaleString("ko-KR")}`}</span>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );
}

/** The entries from the last `n` days, from one reading of the clock. */
function lastDays(items: CoinEntryRow[], n: number) {
  const since = Date.now() - n * 86400000;
  return items.filter((x) => new Date(x.created_at).getTime() >= since);
}
