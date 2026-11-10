import Link from "next/link";
import { seenWelcome } from "./actions";
import styles from "./welcome.module.css";

const DOTS = [[40, 40], [90, 100], [140, 50], [200, 110], [250, 55], [300, 95], [70, 20], [230, 20], [320, 30], [20, 110]];

// Figma W-76 (iOS 21): the first time the plaza opens. Scores and rankings aren't part of it.
export function PlazaWelcome() {
  return (
    <section className={styles.welcome} aria-labelledby="welcome-title">
      <div className={styles.hero} aria-hidden="true">
        {DOTS.map(([x, y], i) => <i key={i} style={{ left: x, top: y, animationDelay: `${(i * 0.37) % 2}s` }} />)}
        <span className={styles.orbit} />
        <span className={styles.orbitInner} />
        <span className={styles.star}><b /></span>
      </div>
      <h1 id="welcome-title" className="h1">우주 광장에 오신 걸<br />환영해요</h1>
      <p className="body-m muted">별지기들이 나눈 별이 모이는 곳이에요.<br />마음에 닿으면 &lsquo;공명&rsquo;이나 &lsquo;별빛 한 줄&rsquo;을 남길 수 있어요.</p>
      <form action={seenWelcome} className={styles.actions}>
        <button className="btn btn-primary btn-block">둘러보기</button>
        <Link href="/" className="btn btn-ghost btn-block">다음에</Link>
      </form>
    </section>
  );
}
