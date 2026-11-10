import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";
import { ChevronLeft, Moon } from "@/components/icons";
import { StatusScreen } from "@/components/Status";
import { PlazaRow } from "@/components/PlazaRow";
import { api, ApiError } from "@/lib/api";
import { requireNickname, withAgo } from "@/lib/plaza";
import { subject } from "@/lib/format";
import type { Keeper } from "@/lib/types";
import styles from "./keeper.module.css";

export const metadata: Metadata = { title: "별지기의 밤하늘" };

// Figma W-50 (기획서 15.3): only the stars this keeper shared. No counts, no starlight, nothing unshared;
// blocked either way, it isn't found.
export default function KeeperPage({ params }: PageProps<"/plaza/keepers/[name]">) {
  return (
    <>
      <Link href="/plaza" className={styles.back}><ChevronLeft size={18} />우주 광장</Link>
      <Suspense fallback={<div className={styles.loading} aria-busy="true" />}>
        <Sky params={params} />
      </Suspense>
    </>
  );
}

async function Sky({ params }: Pick<PageProps<"/plaza/keepers/[name]">, "params">) {
  const { name } = await params;
  const nickname = decodeURIComponent(name);
  await requireNickname(`/plaza/keepers/${name}`);
  let keeper: Keeper;
  try {
    keeper = await api<Keeper>(`/v1/keepers/${encodeURIComponent(nickname)}`);
  } catch (e) {
    // Mobile KeeperPage: a keeper I blocked (or who blocked me, or left) can't be seen.
    if (e instanceof ApiError && e.status === 404) return (
      <StatusScreen icon={<Moon size={22} />} title={`${nickname}의 밤하늘`} body="이 별지기의 밤하늘을 볼 수 없어요.">
        <Link href="/plaza" className="btn btn-primary btn-block">우주 광장으로</Link>
      </StatusScreen>
    );
    throw e;
  }
  await connection();
  const rows = withAgo(keeper.items);
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <h1 className="display">{keeper.nickname}의 밤하늘</h1>
        <p className="body-s muted">
          {keeper.mine ? "다른 별지기에게 보이는 내 밤하늘이에요. " : `${subject(keeper.nickname)} 우주 광장에 나눈 별이에요. `}
          나누지 않은 기록과 수치는 보이지 않아요.
        </p>
      </header>
      <h2 className="h3">나눈 별 {keeper.items.length}</h2>
      {rows.length === 0 ? <p className="body-m faint">아직 나눈 별이 없어요.</p> : (
        <ul className={styles.list}>
          {rows.map(({ star, ago }) => <li key={star.id}><PlazaRow star={star} ago={ago} nickname={false} /></li>)}
        </ul>
      )}
    </div>
  );
}
