import type { Metadata } from "next";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Suspense } from "react";
import { Close } from "@/components/icons";
import { api, ApiError } from "@/lib/api";
import type { Star } from "@/lib/types";
import { EditForm } from "./EditForm";
import styles from "../../../write/write.module.css";

export const metadata: Metadata = { title: "글 수정" };

// Figma W-33: a star without starlight can still change its moods, title and writing.
export default function EditPage({ params }: PageProps<"/stars/[id]/edit">) {
  return (
    <Suspense fallback={<div className={`card ${styles.loading}`} aria-busy="true" />}>
      <Editor params={params} />
    </Suspense>
  );
}

async function Editor({ params }: Pick<PageProps<"/stars/[id]/edit">, "params">) {
  const { id } = await params;
  let star: Star;
  try {
    star = await api<Star>(`/v1/stars/${id}`);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  // A lit star is locked; 고쳐 쓰기 makes a new one instead.
  if (star.locked ?? star.state === "floated") redirect(`/write?rewrite=${id}`);
  return (
    <>
      <div className={styles.top}>
        <Link href={`/stars/${id}`} className={styles.close}><Close size={18} />닫기</Link>
        <span className="label-m">글 수정</span>
        <span className={styles.spacer} />
      </div>
      <EditForm id={id} moods={star.moods ?? [star.mood]} title={star.title} body={star.body} />
    </>
  );
}
