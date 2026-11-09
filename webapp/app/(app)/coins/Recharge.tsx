"use client";

import { loadTossPayments } from "@tosspayments/tosspayments-sdk";
import { useState, useTransition } from "react";
import { ChevronRight, Coin } from "@/components/icons";
import type { CoinsInfo } from "@/lib/types";
import { createOrder } from "./actions";
import styles from "./coins.module.css";

const CLIENT_KEY = process.env.NEXT_PUBLIC_TOSS_CLIENT_KEY;

// Figma W-18 충전하기: pick a package, agree to the payment and refund policy, then Toss's payment window.
export function Recharge({ packages, available, site }: { packages: CoinsInfo["packages"]; available: boolean; site: string }) {
  const [picked, setPicked] = useState(packages.at(-1)?.product_id ?? "");
  const [agreed, setAgreed] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const pack = packages.find((p) => p.product_id === picked);
  const ready = Boolean(CLIENT_KEY) && available;

  const pay = () => start(async () => {
    setError(null);
    if (!pack || !CLIENT_KEY) return;
    const r = await createOrder(pack.product_id);
    if (!r.order) { setError(r.error ?? "주문을 만들지 못했어요."); return; }
    try {
      const toss = await loadTossPayments(CLIENT_KEY);
      await toss.payment({ customerKey: r.order.customer_key }).requestPayment({
        method: "CARD",
        amount: { currency: "KRW", value: r.order.amount },
        orderId: r.order.order_id,
        orderName: r.order.order_name,
        successUrl: `${window.location.origin}/coins/success`,
        failUrl: `${window.location.origin}/coins/fail`,
      });
    } catch (e) {
      // Closing the window is a choice, not an error.
      const code = (e as { code?: string })?.code;
      if (code !== "USER_CANCEL") setError((e as Error)?.message ?? "결제창을 열지 못했어요.");
    }
  });

  return (
    <section className={`card ${styles.recharge}`} aria-labelledby="recharge-title">
      <h2 id="recharge-title" className="h3">충전하기</h2>
      <div className={styles.packs} role="radiogroup" aria-label="코인 상품">
        {packages.map((p) => (
          <button key={p.product_id} type="button" role="radio" aria-checked={p.product_id === picked} className={styles.pack} onClick={() => setPicked(p.product_id)}>
            <span className={styles.coinMark}><Coin size={16} /></span>
            <span className={styles.packText}>
              <span className="h3">{p.coins.toLocaleString("ko-KR")} 코인</span>
              <span className="caption faint">{p.bonus ? `보너스 ${p.bonus} 코인 포함` : `₩${p.price.toLocaleString("ko-KR")}`}</span>
            </span>
            <span className={styles.price}>{p.price.toLocaleString("ko-KR")}원</span>
          </button>
        ))}
      </div>
      <p className="caption faint">충전된 코인만큼 남아 있을 때만 환불할 수 있어요. 결제 후 7일 안에 쓰지 않은 코인은 문의하기로 환불을 요청할 수 있어요.</p>
      <label className={styles.agree}>
        <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} />
        <span>(필수) 결제·환불 정책에 동의해요</span>
        <a href={`${site}/refund`} target="_blank" rel="noreferrer" aria-label="결제·환불 정책 보기"><ChevronRight size={16} /></a>
      </label>
      {!ready && <p className="body-s muted" role="status">지금은 웹 충전을 준비 중이에요. 앱에서 충전해 주세요.</p>}
      {error && <p className="body-s" role="alert" style={{ color: "var(--anger)" }}>{error}</p>}
      <button type="button" className="btn btn-primary btn-block" disabled={!ready || !agreed || !pack || pending} onClick={pay}>
        {!ready ? "웹 충전 준비 중" : pending ? "결제창을 여는 중…" : `${pack?.price.toLocaleString("ko-KR")}원 충전하기`}
      </button>
    </section>
  );
}
