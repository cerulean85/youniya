import Link from "next/link";
import { ChevronLeft } from "@/components/icons";
import styles from "./settings.module.css";

export function Back() {
  return <Link href="/settings" className={styles.back}><ChevronLeft size={16} />설정</Link>;
}
