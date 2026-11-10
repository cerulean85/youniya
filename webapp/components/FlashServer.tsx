import { readFlash } from "@/lib/flash";
import { FlashShow } from "./Flash";

export async function FlashServer() {
  const f = await readFlash();
  return f ? <FlashShow key={f.at} title={f.title} sub={f.sub || undefined} /> : null;
}
