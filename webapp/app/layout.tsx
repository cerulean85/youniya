import type { Metadata, Viewport } from "next";
import { Noto_Sans_KR, Noto_Serif_KR } from "next/font/google";
import "./globals.css";

// Korean glyphs come as Google's unicode-range chunks; only the listed subsets would be preloaded.
const sans = Noto_Sans_KR({ variable: "--font-sans", weight: ["300", "400", "500"], subsets: ["latin"], preload: false });
const serif = Noto_Serif_KR({ variable: "--font-serif", weight: ["400", "500", "600"], subsets: ["latin"], preload: false });

export const metadata: Metadata = {
  metadataBase: new URL("https://app.youniya.dycdyp.com"),
  title: { default: "YOUNIYA", template: "%s · YOUNIYA" },
  description: "쓴 마음이 별이 되는 밤하늘 일기",
  robots: { index: false, follow: false },
};

export const viewport: Viewport = { themeColor: "#0b0f19", colorScheme: "dark" };

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="ko" className={`${sans.variable} ${serif.variable}`}>
      <body>
        <div className="sky" aria-hidden="true" />
        {children}
      </body>
    </html>
  );
}
