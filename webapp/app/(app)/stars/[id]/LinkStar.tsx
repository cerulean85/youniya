"use client";

import Link from "next/link";
import { useEffect, useRef, useState, useTransition } from "react";
import { ChevronLeft, ChevronRight, StarFilled } from "@/components/icons";
import { dateTime, kst, longDate, monthLabel, MOODS, shiftMonth } from "@/lib/format";
import { linkStars, pickerStars, previewStar, type PickItem } from "./actions";
import styles from "./link.module.css";

const FILTERS = [{ key: "all", label: "전체" }, { key: "lit", label: "띄운 별" }, { key: "unlit", label: "별빛 없는 별" },
  ...MOODS.map((m) => ({ key: m.key, label: m.label, color: m.color }))];
const WEEK = ["일", "월", "화", "수", "목", "금", "토"];

type Preview = Awaited<ReturnType<typeof previewStar>>;

// Figma W-47 (이 별과 무엇을 이을까요?), then W-51 list / W-52 calendar / W-53 a star's writing.
export function LinkStar({ id, title, linkedIds }: { id: string; title: string; linkedIds: string[] }) {
  const choose = useRef<HTMLDialogElement>(null);
  const pick = useRef<HTMLDialogElement>(null);
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" className="btn btn-primary btn-block" onClick={() => choose.current?.showModal()}>별 잇기</button>
      <dialog ref={choose} className={`card ${styles.choose}`} aria-labelledby="link-title">
        <h2 id="link-title" className="h2">이 별과 무엇을 이을까요?</h2>
        <p className="body-s muted">이은 별은 서로의 별 상세에 &lsquo;이어진 별&rsquo;로 보여요. 여러 별과 이을 수 있고, 언제든 끊을 수 있어요.</p>
        <Link href={`/write?link=${id}`} className="btn btn-primary btn-block">새 글을 써서 잇기</Link>
        <button type="button" className="btn btn-secondary btn-block" onClick={() => { choose.current?.close(); setOpen(true); pick.current?.showModal(); }}>이미 쓴 별과 잇기</button>
        <button type="button" className="btn btn-ghost" onClick={() => choose.current?.close()}>취소</button>
      </dialog>
      <dialog ref={pick} className={`card ${styles.pick}`} aria-labelledby="pick-title" onClose={() => setOpen(false)}>
        {open && <Picker id={id} title={title} linkedIds={linkedIds} onClose={() => pick.current?.close()} />}
      </dialog>
    </>
  );
}

function Picker({ id, title, linkedIds, onClose }: { id: string; title: string; linkedIds: string[]; onClose: () => void }) {
  const today = kst(new Date()).month;
  const [tab, setTab] = useState<"list" | "calendar">("list");
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState("all");
  const [month, setMonth] = useState(today);
  const [day, setDay] = useState<number | null>(null);
  const [items, setItems] = useState<PickItem[] | null>(null);
  const [chosen, setChosen] = useState<string[]>([]);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, startLoading] = useTransition();
  const [saving, startSaving] = useTransition();

  useEffect(() => {
    const t = setTimeout(() => startLoading(async () => {
      const list = await pickerStars(id, tab === "list" ? { q: q.trim(), filter } : { month });
      setItems(list.filter((s) => !linkedIds.includes(s.id)));
    }), tab === "list" && q ? 300 : 0);
    return () => clearTimeout(t);
  }, [id, tab, q, filter, month, linkedIds]);

  const toggle = (sid: string) => setChosen((c) => (c.includes(sid) ? c.filter((x) => x !== sid) : [...c, sid]));
  const open = (sid: string) => startLoading(async () => setPreview(await previewStar(sid)));
  const submit = () => startSaving(async () => {
    const r = await linkStars(id, chosen);
    if (r?.error) setError(r.error);
    else onClose();
  });

  const shown = tab === "calendar" && day ? (items ?? []).filter((s) => kst(s.created_at).d === day) : items ?? [];
  const groups = new Map<string, PickItem[]>();
  if (tab === "list") for (const s of shown) groups.set(kst(s.created_at).month, [...(groups.get(kst(s.created_at).month) ?? []), s]);

  return (
    <div className={styles.picker}>
      <h2 id="pick-title" className="h1">이을 별 고르기</h2>
      <p className="body-s muted">「{title}」와 이을 별을 골라 주세요. 여러 개 고를 수 있어요.</p>
      <p className="caption" style={{ color: "var(--primary-text)" }}>별을 누르면 내용을 볼 수 있어요 · 오른쪽 원을 누르면 바로 골라져요</p>
      <div className={styles.tabs} role="tablist">
        <button type="button" role="tab" aria-selected={tab === "list"} onClick={() => setTab("list")}>목록</button>
        <button type="button" role="tab" aria-selected={tab === "calendar"} onClick={() => { setTab("calendar"); setDay(null); }}>달력</button>
      </div>
      {tab === "list" ? (
        <>
          <input className={styles.search} type="search" placeholder="제목이나 내용으로 찾기" value={q} onChange={(e) => setQ(e.target.value)} aria-label="별 찾기" />
          <div className={styles.filters}>
            {FILTERS.map((f) => (
              <button key={f.key} type="button" aria-pressed={filter === f.key} onClick={() => setFilter(f.key)}
                style={"color" in f ? { ["--c" as string]: f.color } : undefined} data-dot={"color" in f || undefined}>{f.label}</button>
            ))}
          </div>
        </>
      ) : (
        <Calendar month={month} today={today} items={items ?? []} day={day} setDay={setDay}
          setMonth={(m) => { setMonth(m); setDay(null); }} />
      )}
      <div className={styles.list} aria-busy={loading}>
        {items === null ? <p className="caption faint">불러오는 중…</p>
          : shown.length === 0 ? <p className="caption faint">{tab === "calendar" ? (day ? "이날 쓴 별이 없어요." : "날짜를 누르면 그날의 별이 보여요.") : "이을 수 있는 별이 없어요."}</p>
          : tab === "calendar" ? (
            <>
              {day && <div className={styles.groupHead}><span className="label-m">{longDate(shown[0].created_at)}</span><span className="caption faint">별 {shown.length}개</span></div>}
              {shown.map((s) => <Row key={s.id} s={s} chosen={chosen.includes(s.id)} toggle={toggle} open={open} />)}
            </>
          ) : [...groups].map(([m, list]) => (
            <section key={m}>
              <div className={styles.groupHead}><span className="label-m">{monthLabel(m)}</span><span className="caption faint">별 {list.length}개</span></div>
              {list.map((s) => <Row key={s.id} s={s} chosen={chosen.includes(s.id)} toggle={toggle} open={open} />)}
            </section>
          ))}
      </div>
      {error && <p className="body-s" role="alert">{error}</p>}
      <div className={styles.actions}>
        <button type="button" className="btn btn-ghost" onClick={onClose}>취소</button>
        <button type="button" className="btn btn-primary" disabled={!chosen.length || saving} onClick={submit}>
          {saving ? "잇는 중…" : chosen.length ? `별 ${chosen.length}개 잇기` : "이을 별을 골라 주세요"}
        </button>
      </div>
      {preview && (
        <div className={`card ${styles.preview}`} role="dialog" aria-labelledby="preview-title">
          <p className="caption faint">{longDate(preview.created_at)} · {dateTime(preview.created_at).split(" · ")[1]}{preview.lit ? "" : " · 별빛 없는 별"}</p>
          <h3 id="preview-title" className="h2">{preview.title}</h3>
          <div className={`journal ${styles.previewText}`}>{preview.body}</div>
          {preview.links.length > 0 && (
            <p className="caption" style={{ color: "var(--primary-text)" }}>
              이미 이어진 별 {preview.links.length} · {preview.links.map((l) => `『${l.title}』`).join(" ")}
            </p>
          )}
          <button type="button" className="btn btn-primary btn-block" onClick={() => { if (!chosen.includes(preview.id)) toggle(preview.id); setPreview(null); }}>
            {chosen.includes(preview.id) ? "골랐어요" : "이 별 고르기"}
          </button>
          <button type="button" className="btn btn-ghost" onClick={() => setPreview(null)}>닫기</button>
        </div>
      )}
    </div>
  );
}

function Row({ s, chosen, toggle, open }: { s: PickItem; chosen: boolean; toggle: (id: string) => void; open: (id: string) => void }) {
  return (
    <div className={styles.row} data-chosen={chosen || undefined}>
      <button type="button" className={styles.rowMain} onClick={() => open(s.id)}>
        <StarFilled size={16} className={styles.rowStar} style={{ color: MOODS.find((m) => m.key === s.mood)?.color }} />
        <span>
          <span className="label-m">{s.title}</span>
          <span className="caption faint">{dateTime(s.created_at)}</span>
        </span>
      </button>
      {s.lit && s.starlight != null ? <span className={styles.badge}><StarFilled size={10} />{s.starlight} 별빛</span> : <span className="caption muted">별빛 없는 별</span>}
      <button type="button" className={styles.check} aria-pressed={chosen} aria-label={`${s.title} 고르기`} onClick={() => toggle(s.id)} />
    </div>
  );
}

function Calendar({ month, today, items, day, setDay, setMonth }: {
  month: string; today: string; items: PickItem[]; day: number | null; setDay: (d: number) => void; setMonth: (m: string) => void;
}) {
  const y = Number(month.slice(0, 4)), m = Number(month.slice(5));
  const first = new Date(Date.UTC(y, m - 1, 1)).getUTCDay();
  const days = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const withStars = new Set(items.map((s) => kst(s.created_at).d));
  return (
    <div className={styles.calendar}>
      <div className={styles.calHead}>
        <button type="button" aria-label="이전 달" onClick={() => setMonth(shiftMonth(month, -1))}><ChevronLeft size={18} /></button>
        <span className="h3">{monthLabel(month)}</span>
        <button type="button" aria-label="다음 달" disabled={month >= today} onClick={() => setMonth(shiftMonth(month, 1))}><ChevronRight size={18} /></button>
      </div>
      <div className={styles.grid} role="grid">
        {WEEK.map((w) => <span key={w} className="caption faint">{w}</span>)}
        {Array.from({ length: first }, (_, i) => <span key={`b${i}`} />)}
        {Array.from({ length: days }, (_, i) => i + 1).map((d) => (
          <button key={d} type="button" className={styles.day} disabled={!withStars.has(d)} aria-pressed={day === d} onClick={() => setDay(d)}>
            {d}{withStars.has(d) && <StarFilled size={9} />}
          </button>
        ))}
      </div>
    </div>
  );
}
