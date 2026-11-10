import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Search, Shield, Star, User, ChevronRight, Doc, Info, Lock, LogOut, Moon, Nebula, Phone, Trash, Close } from "@/components/icons";
import { PageHeader } from "@/components/Page";
import { api } from "@/lib/api";
import { SITE_URL } from "@/lib/config";
import { dateTime, fullDate } from "@/lib/format";
import { SKIES, type Me, type MyShare } from "@/lib/types";
import { LogoutButton } from "@/components/LogoutButton";
import { ExportDialog } from "./ExportDialog";
import { DangerZone, MarketingToggle, MotionToggle } from "./SettingsControls";
import styles from "./settings.module.css";

export const metadata: Metadata = { title: "설정" };

const PROVIDERS: Record<string, string> = { apple: "Apple", google: "Google", dev: "테스트", invite: "초대 계정" };

type MeFull = Me & { marketing?: { opt_in: boolean; consented_at: string | null; revoked_at: string | null } };

// Figma W-79 (iOS 87, 87-6): one column of rows; 나눈 별, 차단한 별지기, 별지기 이름 and 우주의 색 open their own pages
// (W-77, W-82, W-80, W-90). 진동, 별 만들기 알림 and 알림 시각 belong to the phone and stay in the app.
export default function SettingsPage({ searchParams }: PageProps<"/settings">) {
  return (
    <div className={styles.page}>
      <PageHeader title="나에게 맞는 밤하늘" sub="필요한 것만 켜 두세요. 언제든 바꿀 수 있어요." />
      <Suspense fallback={<div className={styles.loading} aria-busy="true" />}>
        <Settings searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

const DELETE_NOTE: Record<string, string> = {
  cancel: "Apple 확인을 닫아서 아무것도 지우지 않았어요.",
  retry: "Apple 확인이 끝나지 않았어요. 계정은 그대로예요. 가입할 때 쓴 Apple ID로 다시 시도해 주세요.",
  failed: "계정을 지우지 못했어요. 계정은 그대로예요. 잠시 뒤 다시 시도해 주세요.",
};

async function Settings({ searchParams }: Pick<PageProps<"/settings">, "searchParams">) {
  const sp = await searchParams;
  const note = typeof sp.delete === "string" ? DELETE_NOTE[sp.delete] : undefined;
  const [me, shares, blocks, summary] = await Promise.all([
    api<MeFull>("/v1/me"),
    api<{ stars: MyShare[] }>("/v1/me/shares"),
    api<{ items: unknown[] }>("/v1/blocks"),
    api<{ total: number }>("/v1/stars/summary"),
  ]);
  const marketing = me.marketing ?? { opt_in: Boolean((me as { marketing_opt_in?: boolean }).marketing_opt_in), consented_at: null, revoked_at: null };
  const sky = SKIES.find((s) => s.key === (me.settings?.sky ?? "violet")) ?? SKIES[0];
  return (
    <>
      {note && <p className={styles.notice} role="status">{note}</p>}
      <Group title="계정">
        <div className={styles.row}><Shield size={18} /><span>로그인 계정</span><span className={styles.value}>{PROVIDERS[me.provider] ?? me.provider}</span></div>
        {me.joined_at && <div className={styles.row}><Star size={18} /><span>가입한 날</span><span className={styles.value}>{fullDate(me.joined_at)}</span></div>}
        <Link href="/settings/nickname" className={styles.row}>
          <User size={18} /><span>별지기 이름</span>
          <span className={styles.value}>{me.nickname_rename_required ? <b className={styles.rename}>바꿔 주세요</b> : me.nickname ?? "정하지 않았어요"}<ChevronRight size={16} /></span>
        </Link>
        {me.nickname && <Link href={`/plaza/keepers/${encodeURIComponent(me.nickname)}`} className={styles.row}><Search size={18} /><span>내 별지기 페이지 미리 보기</span><span className={styles.value}><ChevronRight size={16} /></span></Link>}
      </Group>
      <Group title="화면과 움직임">
        <Link href="/settings/sky" className={styles.row}><Moon size={18} /><span>우주의 색</span><span className={styles.value}>{sky.label}<ChevronRight size={16} /></span></Link>
        <MotionToggle on={Boolean(me.settings?.reduce_animations)} />
      </Group>
      <Group title="알림" note={`${marketing.opt_in && marketing.consented_at ? `${dateTime(marketing.consented_at)}에 동의했어요. ` : ""}별 만들기 알림과 알림 시각은 앱에서 정해요. 연속 기록이나 재촉하는 알림은 보내지 않아요.`}>
        <MarketingToggle on={marketing.opt_in} />
      </Group>
      <Group title="우주 광장">
        <Link href="/settings/shares" className={styles.row}><Nebula size={18} /><span>나눈 별</span><span className={styles.value}>{shares.stars.length}개<ChevronRight size={16} /></span></Link>
        <Link href="/settings/blocks" className={styles.row}><Close size={18} /><span>차단한 별지기</span><span className={styles.value}>{blocks.items.length}명<ChevronRight size={16} /></span></Link>
        <DangerZone part="unshare" shared={shares.stars.length} icon={<Lock size={18} />} />
      </Group>
      <Group title="데이터">
        <ExportDialog stars={summary.total} />
        <DangerZone part="delete" shared={shares.stars.length} icon={<Trash size={18} />} apple={me.provider === "apple"} />
      </Group>
      <Group title="도움">
        <a href="tel:109" className={styles.row}><Phone size={18} /><span>24시간 위기 상담</span><span className={styles.value}>109<ChevronRight size={16} /></span></a>
        <a href={`${SITE_URL}/terms`} className={styles.row} target="_blank" rel="noreferrer"><Doc size={18} /><span>약관 및 정책</span><span className={styles.value}><ChevronRight size={16} /></span></a>
        <a href="/contact" className={styles.row}><Info size={18} /><span>문의하기</span><span className={styles.value}><ChevronRight size={16} /></span></a>
        <LogoutButton className={styles.row}><LogOut size={18} /><span>로그아웃</span><span className={styles.value}><ChevronRight size={16} /></span></LogoutButton>
      </Group>
    </>
  );
}

function Group({ title, note, children }: { title: string; note?: string; children: React.ReactNode }) {
  return (
    <section className={styles.group} aria-label={title}>
      <h2 className={`caption faint ${styles.groupTitle}`}>{title}</h2>
      <div className={styles.rows}>{children}</div>
      {note && <p className="caption faint">{note}</p>}
    </section>
  );
}
