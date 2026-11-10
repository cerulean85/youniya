import Link from "next/link";
import { ChevronLeft } from "@/components/icons";
import styles from "./settings.module.css";

export function Back({ href = "/settings", label = "설정" }: { href?: "/settings" | "/plaza"; label?: string }) {
  return <Link href={href} className={styles.back}><ChevronLeft size={16} />{label}</Link>;
}
