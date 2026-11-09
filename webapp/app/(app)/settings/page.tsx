import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { ChevronRight } from "@/components/icons";
import { PageHeader } from "@/components/Page";
import { api } from "@/lib/api";
import { SITE_URL } from "@/lib/config";
import { dateTime, longDate } from "@/lib/format";
import type { Me, MyShare } from "@/lib/types";
import { Blocks, DangerZone, MarketingToggle, NicknameRow } from "./SettingsControls";
import styles from "./settings.module.css";

export const metadata: Metadata = { title: "설정" };

const PROVIDERS: Record<string, string> = { apple: "Apple", google: "Google", dev: "테스트", invite: "초대 계정" };

type Block = { id: string; created_at: string; source: "star" | "line" | "nebula" | string };
type MeFull = Me & { marketing?: { opt_in: boolean; consented_at: string | null; revoked_at: string | null } };

// Figma W-15 (기획서 설정 · 15.1 · 14.3): the web keeps what the web uses. 우주의 색, 진동, 소리와 별 만들기
// 알림 live in the app.
export default function SettingsPage() {
  return (
    <>
      <PageHeader title="설정" sub="나에게 맞는 밤하늘 · 필요한 것만 켜 두세요. 언제든 바꿀 수 있어요." />
      <Suspense fallback={<div className={styles.loading} aria-busy="true" />}>
        <Settings />
      </Suspense>
    </>
  );
}

async function Settings() {
  const [me, shares, blocks] = await Promise.all([
    api<MeFull>("/v1/me"),
    api<{ stars: MyShare[] }>("/v1/me/shares"),
    api<{ items: Block[] }>("/v1/blocks"),
  ]);
  const nextChange = me.nickname_next_change && new Date(me.nickname_next_change) > new Date() ? me.nickname_next_change : null;
  const marketing = me.marketing ?? { opt_in: Boolean((me as { marketing_opt_in?: boolean }).marketing_opt_in), consented_at: null, revoked_at: null };
  return (
    <div className={styles.columns}>
      <div className={styles.column}>
        <Group title="계정">
          <NicknameRow nickname={me.nickname ?? null} nextChange={nextChange ? longDate(nextChange) : null} />
          <div className={styles.row}><span>로그인</span><span className={styles.value}>{PROVIDERS[me.provider] ?? me.provider}로 로그인</span></div>
        </Group>
        <Group title="알림" note={marketing.opt_in && marketing.consented_at ? `${dateTime(marketing.consented_at)}에 동의했어요. 연속 기록이나 재촉하는 알림은 보내지 않아요.` : "연속 기록이나 재촉하는 알림은 보내지 않아요."}>
          <MarketingToggle on={marketing.opt_in} />
        </Group>
        <p className={`caption faint ${styles.appOnly}`}>우주의 색, 진동, 소리, 별 만들기 알림은 앱의 설정에서 바꿀 수 있어요.</p>
      </div>
      <div className={styles.column}>
        <Group title="우주 광장">
          {me.nickname ? (
            <Link href={`/plaza/keepers/${encodeURIComponent(me.nickname)}`} className={styles.row}>
              <span>나눈 별</span><span className={styles.value}>{shares.stars.length}개<ChevronRight size={16} /></span>
            </Link>
          ) : <div className={styles.row}><span>나눈 별</span><span className={styles.value}>{shares.stars.length}개</span></div>}
          <Blocks blocks={blocks.items.map((b) => ({ id: b.id, when: longDate(b.created_at), where: b.source === "line" ? "별빛 한 줄에서" : b.source === "nebula" ? "성운에서" : "광장의 별에서" }))} />
        </Group>
        <Group title="데이터">
          <a href="/settings/export" className={styles.row} download><span>데이터 내보내기</span><span className={styles.value}>텍스트 파일<ChevronRight size={16} /></span></a>
          <DangerZone shared={shares.stars.length} />
        </Group>
        <Group title="도움">
          <a href="tel:109" className={styles.row}><span>24시간 위기 상담</span><span className={styles.value}>109<ChevronRight size={16} /></span></a>
          <a href={`${SITE_URL}/terms`} className={styles.row} target="_blank" rel="noreferrer"><span>이용약관</span><ChevronRight size={16} /></a>
          <a href={`${SITE_URL}/privacy`} className={styles.row} target="_blank" rel="noreferrer"><span>개인정보 처리방침</span><ChevronRight size={16} /></a>
          <form action="/auth/logout" method="post"><button className={styles.row}><span>로그아웃</span><ChevronRight size={16} /></button></form>
        </Group>
      </div>
    </div>
  );
}

function Group({ title, note, children }: { title: string; note?: string; children: React.ReactNode }) {
  return (
    <section className={styles.group}>
      <h2 className="label-s muted">{title}</h2>
      <div className={`card ${styles.card}`}>{children}</div>
      {note && <p className="caption faint">{note}</p>}
    </section>
  );
}
