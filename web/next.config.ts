import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // Force a unique build ID per build so chunk hashes change, busting
  // any downstream CDN/proxy cache (Cloudflare, nginx, browser).
  generateBuildId: async () => `build-${Date.now()}`,
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "cdn.myanimelist.net" },
      { protocol: "https", hostname: "img.anili.st" },
      { protocol: "https", hostname: "uploads.mangadex.org" },
      { protocol: "https", hostname: "image.tmdb.org" },
      { protocol: "https", hostname: "s4.anilist.co" },
    ],
  },
  // Set aggressive no-store on HTML so browsers/CDN always fetch fresh
  // HTML (which references the new hashed chunks). Static assets keep
  // their immutable caching (hashes change so no stale risk).
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "Cache-Control", value: "no-store, must-revalidate" },
        ],
      },
      {
        source: "/_next/static/:path*",
        headers: [
          {
            key: "Cache-Control",
            value: "public, max-age=31536000, immutable",
          },
        ],
      },
    ];
  },
};

export default nextConfig;
