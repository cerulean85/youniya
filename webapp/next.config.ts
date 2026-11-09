import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  // 2026-11-09: nebulae became monthly constellations (별자리); the mind telescope lives in star detail.
  async redirects() {
    return [
      { source: "/nebula/:path*", destination: "/constellation", permanent: false },
      { source: "/telescope", destination: "/", permanent: false },
    ];
  },
};

export default nextConfig;
