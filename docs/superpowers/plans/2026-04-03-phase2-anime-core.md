# Phase 2: Anime Core — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the anime browsing, detail, streaming, and scheduling experience -- home page with featured carousel and 6 category sections, anime browse/list with pagination, anime detail page, HLS video player with progress tracking and source switching, and airing calendar.

**Architecture:** Next.js 16 App Router with all anime pages under `app/(main)/`. AnimeService wraps the backend REST API at `:3005` using the Phase 1 `apiClient` singleton. SourceContext (React Context) manages the active anime source globally. Video playback uses native HTML5 `<video>` enhanced by hls.js for HLS/m3u8 streams, with a 10-second interval `POST /users/progress` for watch tracking. Pages are client components (`"use client"`) since they rely on context and browser APIs.

**Tech Stack:** Next.js 16, React 19, Tailwind CSS v4, TypeScript, hls.js (HLS streaming)

---

## File Structure

```
web/
├── app/(main)/
│   ├── home/page.tsx                          # Modify: full home page
│   ├── anime/
│   │   ├── page.tsx                           # Create: browse/list with filters
│   │   └── [id]/
│   │       ├── page.tsx                       # Create: anime detail
│   │       └── player/
│   │           └── [episodeId]/page.tsx        # Create: video player page
│   └── calendar/page.tsx                      # Create: airing schedule
├── components/
│   ├── anime/
│   │   ├── AnimeCard.tsx                      # Create: grid card component
│   │   ├── AnimeCategorySection.tsx            # Create: horizontal scroll section
│   │   ├── FeaturedCarousel.tsx                # Create: hero banner carousel
│   │   ├── AnimeHero.tsx                      # Create: detail page banner
│   │   ├── EpisodeCard.tsx                    # Create: single episode card
│   │   └── EpisodeList.tsx                    # Create: episode grid/list
│   ├── player/
│   │   ├── VideoPlayer.tsx                    # Create: HLS + MP4 player
│   │   ├── PlayerControls.tsx                 # Create: custom controls overlay
│   │   └── EpisodeSidebar.tsx                 # Create: episode list sidebar
│   └── common/
│       └── InfiniteScroll.tsx                 # Create: intersection observer
├── contexts/
│   └── SourceContext.tsx                       # Create: anime source state
└── services/
    └── anime.service.ts                       # Create: all anime API methods
```

---

### Task 1: Install hls.js Dependency

**Files:**
- Modify: `web/package.json`

- [ ] **Step 1: Install hls.js**

```bash
cd web
npm install hls.js
```

- [ ] **Step 2: Commit**

```bash
git add web/package.json web/package-lock.json
git commit -m "feat(web): install hls.js for HLS video streaming"
```

---

### Task 2: Create Anime Service

**Files:**
- Create: `web/services/anime.service.ts`

- [ ] **Step 1: Create `web/services/anime.service.ts`**

```typescript
import { apiClient } from "./api-client";
import type { PaginatedResult } from "@/types/api";
import type { Anime, Episode, AnimeSource } from "@/types/anime";

export interface AnimeListFilters {
  page?: number;
  limit?: number;
  genre?: string;
  status?: string;
  search?: string;
  sort?: string;
}

export const animeService = {
  async getAnimeList(
    filters: AnimeListFilters = {},
  ): Promise<PaginatedResult<Anime>> {
    const params: Record<string, string | number | undefined> = {
      page: filters.page,
      limit: filters.limit,
      genre: filters.genre,
      status: filters.status,
      search: filters.search,
      sort: filters.sort,
    };
    return apiClient.get<PaginatedResult<Anime>>("/anime", params);
  },

  async getNewReleases(
    page: number = 1,
    limit: number = 20,
  ): Promise<PaginatedResult<Anime>> {
    return apiClient.get<PaginatedResult<Anime>>("/anime/new-releases", {
      page,
      limit,
    });
  },

  async getTopRated(
    page: number = 1,
    limit: number = 20,
  ): Promise<PaginatedResult<Anime>> {
    return apiClient.get<PaginatedResult<Anime>>("/anime/top-rated", {
      page,
      limit,
    });
  },

  async getPopular(
    page: number = 1,
    limit: number = 20,
  ): Promise<PaginatedResult<Anime>> {
    return apiClient.get<PaginatedResult<Anime>>("/anime", {
      page,
      limit,
      sort: "popularity",
    });
  },

  async getAiring(
    page: number = 1,
    limit: number = 20,
  ): Promise<PaginatedResult<Anime>> {
    return apiClient.get<PaginatedResult<Anime>>("/anime", {
      page,
      limit,
      status: "ongoing",
    });
  },

  async getClassics(
    page: number = 1,
    limit: number = 20,
  ): Promise<PaginatedResult<Anime>> {
    return apiClient.get<PaginatedResult<Anime>>("/anime", {
      page,
      limit,
      sort: "rating",
      status: "completed",
    });
  },

  async getUpcoming(
    page: number = 1,
    limit: number = 20,
  ): Promise<PaginatedResult<Anime>> {
    return apiClient.get<PaginatedResult<Anime>>("/anime", {
      page,
      limit,
      status: "upcoming",
    });
  },

  async getAnimeById(id: string): Promise<Anime> {
    return apiClient.get<Anime>(`/anime/${id}`);
  },

  async getEpisodes(animeId: string): Promise<Episode[]> {
    return apiClient.get<Episode[]>(`/anime/${animeId}/episodes`);
  },

  async getSources(): Promise<AnimeSource[]> {
    return apiClient.get<AnimeSource[]>("/anime/sources");
  },

  async setActiveSource(sourceId: string): Promise<void> {
    return apiClient.post<void>(`/anime/sources/${sourceId}/activate`);
  },

  async getSchedule(
    day?: string,
  ): Promise<Anime[]> {
    return apiClient.get<Anime[]>("/jikan/anime/schedule", {
      day,
    });
  },

  async getGenres(): Promise<string[]> {
    return apiClient.get<string[]>("/anime/genres");
  },
};
```

- [ ] **Step 2: Commit**

```bash
git add web/services/anime.service.ts
git commit -m "feat(web): add anime service with all API methods"
```

---

### Task 3: Create SourceContext

**Files:**
- Create: `web/contexts/SourceContext.tsx`

- [ ] **Step 1: Create `web/contexts/SourceContext.tsx`**

```tsx
"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  type ReactNode,
} from "react";
import type { AnimeSource } from "@/types/anime";
import { animeService } from "@/services/anime.service";

interface SourceContextType {
  sources: AnimeSource[];
  activeSource: AnimeSource | null;
  loading: boolean;
  error: string | null;
  setActiveSource: (sourceId: string) => Promise<void>;
  refreshSources: () => Promise<void>;
}

const SourceContext = createContext<SourceContextType | undefined>(undefined);

export function SourceProvider({ children }: { children: ReactNode }) {
  const [sources, setSources] = useState<AnimeSource[]>([]);
  const [activeSource, setActiveSourceState] = useState<AnimeSource | null>(
    null,
  );
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refreshSources = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await animeService.getSources();
      setSources(data);
      const active = data.find((s) => s.isActive) || data[0] || null;
      setActiveSourceState(active);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to load anime sources",
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refreshSources();
  }, [refreshSources]);

  const setActiveSource = useCallback(
    async (sourceId: string) => {
      try {
        await animeService.setActiveSource(sourceId);
        const updated = sources.map((s) => ({
          ...s,
          isActive: s.id === sourceId,
        }));
        setSources(updated);
        setActiveSourceState(updated.find((s) => s.isActive) || null);
      } catch (err) {
        setError(
          err instanceof Error ? err.message : "Failed to switch source",
        );
      }
    },
    [sources],
  );

  return (
    <SourceContext.Provider
      value={{
        sources,
        activeSource,
        loading,
        error,
        setActiveSource,
        refreshSources,
      }}
    >
      {children}
    </SourceContext.Provider>
  );
}

export function useSource() {
  const context = useContext(SourceContext);
  if (!context) {
    throw new Error("useSource must be used within a SourceProvider");
  }
  return context;
}
```

- [ ] **Step 2: Add SourceProvider to root layout**

In `web/app/layout.tsx`, wrap children with `<SourceProvider>` inside the existing `<AuthProvider>`:

```tsx
import { SourceProvider } from "@/contexts/SourceContext";

// Inside the RootLayout return, wrap the children:
<AuthProvider>
  <SourceProvider>
    {children}
  </SourceProvider>
</AuthProvider>
```

- [ ] **Step 3: Commit**

```bash
git add web/contexts/SourceContext.tsx web/app/layout.tsx
git commit -m "feat(web): add SourceContext for anime source management"
```

---

### Task 4: Create AnimeCard Component

**Files:**
- Create: `web/components/anime/AnimeCard.tsx`

- [ ] **Step 1: Create `web/components/anime/AnimeCard.tsx`**

```tsx
"use client";

import Link from "next/link";
import Image from "next/image";
import { cn } from "@/lib/utils";
import type { Anime } from "@/types/anime";

interface AnimeCardProps {
  anime: Anime;
  className?: string;
}

const statusColors: Record<string, string> = {
  ongoing: "bg-green-500",
  completed: "bg-blue-500",
  upcoming: "bg-yellow-500",
};

export function AnimeCard({ anime, className }: AnimeCardProps) {
  return (
    <Link
      href={`/anime/${anime.id}`}
      className={cn(
        "group relative flex flex-col rounded-lg overflow-hidden bg-[var(--color-surface)] hover:bg-[var(--color-surface-hover)] transition-all duration-200 hover:scale-[1.02] hover:shadow-lg hover:shadow-black/20",
        className,
      )}
    >
      {/* Cover Image */}
      <div className="relative aspect-[3/4] w-full overflow-hidden">
        {anime.coverUrl ? (
          <Image
            src={anime.coverUrl}
            alt={anime.title}
            fill
            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 20vw"
            className="object-cover transition-transform duration-300 group-hover:scale-105"
          />
        ) : (
          <div className="w-full h-full bg-[var(--color-border)] flex items-center justify-center">
            <svg
              className="w-12 h-12 text-[var(--color-text-muted)]"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1.5}
                d="M15.75 10.5l4.72-4.72a.75.75 0 011.28.53v11.38a.75.75 0 01-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 002.25-2.25v-9a2.25 2.25 0 00-2.25-2.25h-9A2.25 2.25 0 002.25 7.5v9a2.25 2.25 0 002.25 2.25z"
              />
            </svg>
          </div>
        )}

        {/* Status Badge */}
        <span
          className={cn(
            "absolute top-2 left-2 px-2 py-0.5 text-xs font-semibold rounded-full text-white capitalize",
            statusColors[anime.status] || "bg-gray-500",
          )}
        >
          {anime.status}
        </span>

        {/* Rating Badge */}
        {anime.rating > 0 && (
          <span className="absolute top-2 right-2 px-2 py-0.5 text-xs font-bold rounded-full bg-black/70 text-yellow-400 flex items-center gap-1">
            <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
            </svg>
            {anime.rating.toFixed(1)}
          </span>
        )}

        {/* Gradient overlay at bottom */}
        <div className="absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-black/80 to-transparent" />
      </div>

      {/* Info */}
      <div className="p-3 flex flex-col gap-1.5">
        <h3 className="text-sm font-semibold text-[var(--color-text)] line-clamp-2 leading-tight">
          {anime.title}
        </h3>

        {/* Genres */}
        {anime.genres && anime.genres.length > 0 && (
          <div className="flex flex-wrap gap-1">
            {anime.genres.slice(0, 3).map((genre) => (
              <span
                key={genre}
                className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--color-border)] text-[var(--color-text-muted)]"
              >
                {genre}
              </span>
            ))}
          </div>
        )}

        {/* Meta row */}
        <div className="flex items-center justify-between text-xs text-[var(--color-text-muted)]">
          <span>{anime.releaseYear}</span>
          {anime.totalEpisodes > 0 && (
            <span>{anime.totalEpisodes} eps</span>
          )}
        </div>
      </div>
    </Link>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/anime/AnimeCard.tsx
git commit -m "feat(web): add AnimeCard component with cover, rating, status badge"
```

---

### Task 5: Create AnimeCategorySection Component

**Files:**
- Create: `web/components/anime/AnimeCategorySection.tsx`

- [ ] **Step 1: Create `web/components/anime/AnimeCategorySection.tsx`**

```tsx
"use client";

import { useRef } from "react";
import Link from "next/link";
import { cn } from "@/lib/utils";
import type { Anime } from "@/types/anime";
import { AnimeCard } from "./AnimeCard";
import { Skeleton } from "@/components/ui/Skeleton";

interface AnimeCategorySectionProps {
  title: string;
  anime: Anime[];
  loading?: boolean;
  seeAllHref?: string;
  className?: string;
}

export function AnimeCategorySection({
  title,
  anime,
  loading = false,
  seeAllHref,
  className,
}: AnimeCategorySectionProps) {
  const scrollRef = useRef<HTMLDivElement>(null);

  const scroll = (direction: "left" | "right") => {
    if (!scrollRef.current) return;
    const scrollAmount = scrollRef.current.clientWidth * 0.8;
    scrollRef.current.scrollBy({
      left: direction === "left" ? -scrollAmount : scrollAmount,
      behavior: "smooth",
    });
  };

  return (
    <section className={cn("space-y-4", className)}>
      {/* Header */}
      <div className="flex items-center justify-between px-1">
        <h2 className="text-xl font-bold text-[var(--color-text)]">{title}</h2>
        <div className="flex items-center gap-2">
          {/* Scroll arrows */}
          <button
            onClick={() => scroll("left")}
            className="p-1.5 rounded-full bg-[var(--color-surface)] hover:bg-[var(--color-surface-hover)] text-[var(--color-text-muted)] transition-colors hidden md:flex"
            aria-label="Scroll left"
          >
            <svg
              className="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M15 19l-7-7 7-7"
              />
            </svg>
          </button>
          <button
            onClick={() => scroll("right")}
            className="p-1.5 rounded-full bg-[var(--color-surface)] hover:bg-[var(--color-surface-hover)] text-[var(--color-text-muted)] transition-colors hidden md:flex"
            aria-label="Scroll right"
          >
            <svg
              className="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M9 5l7 7-7 7"
              />
            </svg>
          </button>

          {seeAllHref && (
            <Link
              href={seeAllHref}
              className="text-sm text-[var(--color-primary)] hover:text-[var(--color-primary-hover)] font-medium transition-colors"
            >
              See all
            </Link>
          )}
        </div>
      </div>

      {/* Scrollable row */}
      <div
        ref={scrollRef}
        className="flex gap-4 overflow-x-auto scrollbar-hide pb-2 snap-x snap-mandatory"
        style={{ scrollbarWidth: "none", msOverflowStyle: "none" }}
      >
        {loading
          ? Array.from({ length: 8 }).map((_, i) => (
              <div
                key={i}
                className="flex-shrink-0 w-[140px] sm:w-[160px] md:w-[180px]"
              >
                <Skeleton className="aspect-[3/4] w-full rounded-lg" />
                <Skeleton className="h-4 w-3/4 mt-2 rounded" />
                <Skeleton className="h-3 w-1/2 mt-1 rounded" />
              </div>
            ))
          : anime.map((item) => (
              <AnimeCard
                key={item.id}
                anime={item}
                className="flex-shrink-0 w-[140px] sm:w-[160px] md:w-[180px] snap-start"
              />
            ))}
      </div>
    </section>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/anime/AnimeCategorySection.tsx
git commit -m "feat(web): add AnimeCategorySection with horizontal scroll and See all link"
```

---

### Task 6: Create FeaturedCarousel Component

**Files:**
- Create: `web/components/anime/FeaturedCarousel.tsx`

- [ ] **Step 1: Create `web/components/anime/FeaturedCarousel.tsx`**

```tsx
"use client";

import { useState, useEffect, useCallback } from "react";
import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/utils";
import type { Anime } from "@/types/anime";
import { Skeleton } from "@/components/ui/Skeleton";

interface FeaturedCarouselProps {
  anime: Anime[];
  loading?: boolean;
  className?: string;
}

export function FeaturedCarousel({
  anime,
  loading = false,
  className,
}: FeaturedCarouselProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPaused, setIsPaused] = useState(false);

  const goToNext = useCallback(() => {
    if (anime.length === 0) return;
    setCurrentIndex((prev) => (prev + 1) % anime.length);
  }, [anime.length]);

  const goToPrev = useCallback(() => {
    if (anime.length === 0) return;
    setCurrentIndex((prev) => (prev - 1 + anime.length) % anime.length);
  }, [anime.length]);

  const goToSlide = useCallback((index: number) => {
    setCurrentIndex(index);
  }, []);

  // Auto-slide every 6 seconds
  useEffect(() => {
    if (isPaused || anime.length <= 1) return;
    const timer = setInterval(goToNext, 6000);
    return () => clearInterval(timer);
  }, [goToNext, isPaused, anime.length]);

  if (loading) {
    return (
      <div className={cn("relative w-full aspect-[21/9] rounded-xl overflow-hidden", className)}>
        <Skeleton className="w-full h-full" />
      </div>
    );
  }

  if (anime.length === 0) return null;

  const current = anime[currentIndex];

  return (
    <div
      className={cn("relative w-full aspect-[21/9] min-h-[300px] max-h-[500px] rounded-xl overflow-hidden", className)}
      onMouseEnter={() => setIsPaused(true)}
      onMouseLeave={() => setIsPaused(false)}
    >
      {/* Background Image */}
      <div className="absolute inset-0">
        {current.bannerImage || current.coverUrl ? (
          <Image
            src={current.bannerImage || current.coverUrl || ""}
            alt={current.title}
            fill
            priority
            sizes="100vw"
            className="object-cover transition-opacity duration-700"
          />
        ) : (
          <div className="w-full h-full bg-gradient-to-r from-[var(--color-surface)] to-[var(--color-bg)]" />
        )}

        {/* Overlays */}
        <div className="absolute inset-0 bg-gradient-to-r from-black/80 via-black/50 to-transparent" />
        <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />
      </div>

      {/* Content */}
      <div className="relative z-10 flex flex-col justify-end h-full p-6 sm:p-8 md:p-12 max-w-2xl">
        {/* Status + Rating */}
        <div className="flex items-center gap-3 mb-3">
          <span className="px-3 py-1 text-xs font-bold rounded-full bg-[var(--color-primary)] text-white uppercase">
            {current.status}
          </span>
          {current.rating > 0 && (
            <span className="flex items-center gap-1 text-yellow-400 text-sm font-semibold">
              <svg
                className="w-4 h-4"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
              </svg>
              {current.rating.toFixed(1)}
            </span>
          )}
          {current.releaseYear && (
            <span className="text-sm text-gray-300">{current.releaseYear}</span>
          )}
        </div>

        {/* Title */}
        <h1 className="text-2xl sm:text-3xl md:text-4xl font-bold text-white mb-2 line-clamp-2">
          {current.title}
        </h1>

        {/* Synopsis */}
        {(current.synopsis || current.description) && (
          <p className="text-sm sm:text-base text-gray-300 line-clamp-2 mb-4 max-w-lg">
            {current.synopsis || current.description}
          </p>
        )}

        {/* Genres */}
        {current.genres && current.genres.length > 0 && (
          <div className="flex flex-wrap gap-2 mb-5">
            {current.genres.slice(0, 4).map((genre) => (
              <span
                key={genre}
                className="text-xs px-2.5 py-1 rounded-full border border-white/20 text-gray-200"
              >
                {genre}
              </span>
            ))}
          </div>
        )}

        {/* Actions */}
        <div className="flex items-center gap-3">
          <Link
            href={`/anime/${current.id}`}
            className="inline-flex items-center gap-2 px-6 py-2.5 bg-[var(--color-primary)] hover:bg-[var(--color-primary-hover)] text-white font-semibold rounded-lg transition-colors"
          >
            <svg
              className="w-5 h-5"
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path
                fillRule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z"
                clipRule="evenodd"
              />
            </svg>
            Watch Now
          </Link>
          <Link
            href={`/anime/${current.id}`}
            className="inline-flex items-center gap-2 px-6 py-2.5 bg-white/10 hover:bg-white/20 text-white font-semibold rounded-lg border border-white/20 transition-colors"
          >
            Details
          </Link>
        </div>
      </div>

      {/* Navigation Arrows */}
      {anime.length > 1 && (
        <>
          <button
            onClick={goToPrev}
            className="absolute left-3 top-1/2 -translate-y-1/2 z-20 p-2 rounded-full bg-black/40 hover:bg-black/60 text-white transition-colors"
            aria-label="Previous slide"
          >
            <svg
              className="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M15 19l-7-7 7-7"
              />
            </svg>
          </button>
          <button
            onClick={goToNext}
            className="absolute right-3 top-1/2 -translate-y-1/2 z-20 p-2 rounded-full bg-black/40 hover:bg-black/60 text-white transition-colors"
            aria-label="Next slide"
          >
            <svg
              className="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M9 5l7 7-7 7"
              />
            </svg>
          </button>
        </>
      )}

      {/* Dot Indicators */}
      {anime.length > 1 && (
        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 z-20 flex items-center gap-2">
          {anime.map((_, index) => (
            <button
              key={index}
              onClick={() => goToSlide(index)}
              className={cn(
                "rounded-full transition-all duration-300",
                index === currentIndex
                  ? "w-8 h-2 bg-[var(--color-primary)]"
                  : "w-2 h-2 bg-white/40 hover:bg-white/60",
              )}
              aria-label={`Go to slide ${index + 1}`}
            />
          ))}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/anime/FeaturedCarousel.tsx
git commit -m "feat(web): add FeaturedCarousel with auto-slide, arrows, and dot indicators"
```

---

### Task 7: Build Home Page

**Files:**
- Modify: `web/app/(main)/home/page.tsx`

- [ ] **Step 1: Replace `web/app/(main)/home/page.tsx`**

```tsx
"use client";

import { useState, useEffect } from "react";
import type { Anime } from "@/types/anime";
import { animeService } from "@/services/anime.service";
import { FeaturedCarousel } from "@/components/anime/FeaturedCarousel";
import { AnimeCategorySection } from "@/components/anime/AnimeCategorySection";

interface CategoryData {
  anime: Anime[];
  loading: boolean;
}

export default function HomePage() {
  const [featured, setFeatured] = useState<CategoryData>({
    anime: [],
    loading: true,
  });
  const [newReleases, setNewReleases] = useState<CategoryData>({
    anime: [],
    loading: true,
  });
  const [topRated, setTopRated] = useState<CategoryData>({
    anime: [],
    loading: true,
  });
  const [popular, setPopular] = useState<CategoryData>({
    anime: [],
    loading: true,
  });
  const [airing, setAiring] = useState<CategoryData>({
    anime: [],
    loading: true,
  });
  const [classics, setClassics] = useState<CategoryData>({
    anime: [],
    loading: true,
  });
  const [upcoming, setUpcoming] = useState<CategoryData>({
    anime: [],
    loading: true,
  });

  useEffect(() => {
    // Featured carousel: top rated with banner images
    animeService
      .getTopRated(1, 8)
      .then((res) => setFeatured({ anime: res.data, loading: false }))
      .catch(() => setFeatured((prev) => ({ ...prev, loading: false })));

    // New Releases
    animeService
      .getNewReleases(1, 20)
      .then((res) => setNewReleases({ anime: res.data, loading: false }))
      .catch(() => setNewReleases((prev) => ({ ...prev, loading: false })));

    // Top Rated
    animeService
      .getTopRated(1, 20)
      .then((res) => setTopRated({ anime: res.data, loading: false }))
      .catch(() => setTopRated((prev) => ({ ...prev, loading: false })));

    // Popular
    animeService
      .getPopular(1, 20)
      .then((res) => setPopular({ anime: res.data, loading: false }))
      .catch(() => setPopular((prev) => ({ ...prev, loading: false })));

    // Airing
    animeService
      .getAiring(1, 20)
      .then((res) => setAiring({ anime: res.data, loading: false }))
      .catch(() => setAiring((prev) => ({ ...prev, loading: false })));

    // Classics
    animeService
      .getClassics(1, 20)
      .then((res) => setClassics({ anime: res.data, loading: false }))
      .catch(() => setClassics((prev) => ({ ...prev, loading: false })));

    // Upcoming
    animeService
      .getUpcoming(1, 20)
      .then((res) => setUpcoming({ anime: res.data, loading: false }))
      .catch(() => setUpcoming((prev) => ({ ...prev, loading: false })));
  }, []);

  return (
    <div className="space-y-10 pb-10">
      {/* Featured Carousel */}
      <FeaturedCarousel anime={featured.anime} loading={featured.loading} />

      {/* Category Sections */}
      <AnimeCategorySection
        title="New Releases"
        anime={newReleases.anime}
        loading={newReleases.loading}
        seeAllHref="/anime?sort=newest"
      />

      <AnimeCategorySection
        title="Top Rated"
        anime={topRated.anime}
        loading={topRated.loading}
        seeAllHref="/anime?sort=rating"
      />

      <AnimeCategorySection
        title="Popular"
        anime={popular.anime}
        loading={popular.loading}
        seeAllHref="/anime?sort=popularity"
      />

      <AnimeCategorySection
        title="Currently Airing"
        anime={airing.anime}
        loading={airing.loading}
        seeAllHref="/anime?status=ongoing"
      />

      <AnimeCategorySection
        title="Classics"
        anime={classics.anime}
        loading={classics.loading}
        seeAllHref="/anime?status=completed&sort=rating"
      />

      <AnimeCategorySection
        title="Upcoming"
        anime={upcoming.anime}
        loading={upcoming.loading}
        seeAllHref="/anime?status=upcoming"
      />
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/home/page.tsx
git commit -m "feat(web): build home page with featured carousel and 6 category sections"
```

---

### Task 8: Create Anime Browse/List Page

**Files:**
- Create: `web/app/(main)/anime/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/anime/page.tsx`**

```tsx
"use client";

import { useState, useEffect, useCallback } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import type { Anime } from "@/types/anime";
import { animeService } from "@/services/anime.service";
import { AnimeCard } from "@/components/anime/AnimeCard";
import { InfiniteScroll } from "@/components/common/InfiniteScroll";
import { Skeleton } from "@/components/ui/Skeleton";
import { cn } from "@/lib/utils";

const STATUS_OPTIONS = [
  { label: "All", value: "" },
  { label: "Ongoing", value: "ongoing" },
  { label: "Completed", value: "completed" },
  { label: "Upcoming", value: "upcoming" },
];

export default function AnimeBrowsePage() {
  const searchParams = useSearchParams();
  const router = useRouter();

  const [anime, setAnime] = useState<Anime[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [genres, setGenres] = useState<string[]>([]);

  const selectedGenre = searchParams.get("genre") || "";
  const selectedStatus = searchParams.get("status") || "";
  const selectedSort = searchParams.get("sort") || "";

  // Load genres on mount
  useEffect(() => {
    animeService
      .getGenres()
      .then(setGenres)
      .catch(() => {});
  }, []);

  // Load anime when filters change
  useEffect(() => {
    setLoading(true);
    setPage(1);
    setAnime([]);
    setHasMore(true);

    animeService
      .getAnimeList({
        page: 1,
        limit: 24,
        genre: selectedGenre || undefined,
        status: selectedStatus || undefined,
        sort: selectedSort || undefined,
      })
      .then((res) => {
        setAnime(res.data);
        setHasMore(res.page < res.totalPages);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [selectedGenre, selectedStatus, selectedSort]);

  // Load more for infinite scroll
  const loadMore = useCallback(async () => {
    if (loadingMore || !hasMore) return;
    setLoadingMore(true);
    const nextPage = page + 1;

    try {
      const res = await animeService.getAnimeList({
        page: nextPage,
        limit: 24,
        genre: selectedGenre || undefined,
        status: selectedStatus || undefined,
        sort: selectedSort || undefined,
      });
      setAnime((prev) => [...prev, ...res.data]);
      setPage(nextPage);
      setHasMore(res.page < res.totalPages);
    } catch {
      // Silently fail, user can scroll again
    } finally {
      setLoadingMore(false);
    }
  }, [loadingMore, hasMore, page, selectedGenre, selectedStatus, selectedSort]);

  const updateFilter = (key: string, value: string) => {
    const params = new URLSearchParams(searchParams.toString());
    if (value) {
      params.set(key, value);
    } else {
      params.delete(key);
    }
    router.push(`/anime?${params.toString()}`);
  };

  return (
    <div className="space-y-6 pb-10">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-bold text-[var(--color-text)]">
          Browse Anime
        </h1>
        <p className="text-sm text-[var(--color-text-muted)] mt-1">
          Discover your next favorite anime
        </p>
      </div>

      {/* Filters */}
      <div className="space-y-4">
        {/* Status Filter */}
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-sm font-medium text-[var(--color-text-muted)] mr-1">
            Status:
          </span>
          {STATUS_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              onClick={() => updateFilter("status", opt.value)}
              className={cn(
                "px-3 py-1.5 text-sm rounded-full transition-colors",
                selectedStatus === opt.value
                  ? "bg-[var(--color-primary)] text-white"
                  : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]",
              )}
            >
              {opt.label}
            </button>
          ))}
        </div>

        {/* Genre Filter */}
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-sm font-medium text-[var(--color-text-muted)] mr-1">
            Genre:
          </span>
          <button
            onClick={() => updateFilter("genre", "")}
            className={cn(
              "px-3 py-1.5 text-sm rounded-full transition-colors",
              selectedGenre === ""
                ? "bg-[var(--color-primary)] text-white"
                : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]",
            )}
          >
            All
          </button>
          {genres.map((genre) => (
            <button
              key={genre}
              onClick={() => updateFilter("genre", genre)}
              className={cn(
                "px-3 py-1.5 text-sm rounded-full transition-colors",
                selectedGenre === genre
                  ? "bg-[var(--color-primary)] text-white"
                  : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]",
              )}
            >
              {genre}
            </button>
          ))}
        </div>
      </div>

      {/* Anime Grid */}
      {loading ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
          {Array.from({ length: 24 }).map((_, i) => (
            <div key={i}>
              <Skeleton className="aspect-[3/4] w-full rounded-lg" />
              <Skeleton className="h-4 w-3/4 mt-2 rounded" />
              <Skeleton className="h-3 w-1/2 mt-1 rounded" />
            </div>
          ))}
        </div>
      ) : anime.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-center">
          <svg
            className="w-16 h-16 text-[var(--color-text-muted)] mb-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1.5}
              d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
            />
          </svg>
          <p className="text-lg text-[var(--color-text-muted)]">
            No anime found matching your filters
          </p>
          <button
            onClick={() => router.push("/anime")}
            className="mt-4 text-sm text-[var(--color-primary)] hover:underline"
          >
            Clear all filters
          </button>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
            {anime.map((item) => (
              <AnimeCard key={item.id} anime={item} />
            ))}
          </div>

          {/* Infinite Scroll Trigger */}
          <InfiniteScroll
            onLoadMore={loadMore}
            hasMore={hasMore}
            loading={loadingMore}
          />
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/anime/page.tsx
git commit -m "feat(web): add anime browse page with genre/status filters and infinite scroll"
```

---

### Task 9: Create InfiniteScroll Component

**Files:**
- Create: `web/components/common/InfiniteScroll.tsx`

- [ ] **Step 1: Create `web/components/common/InfiniteScroll.tsx`**

```tsx
"use client";

import { useEffect, useRef } from "react";
import { Skeleton } from "@/components/ui/Skeleton";

interface InfiniteScrollProps {
  onLoadMore: () => void;
  hasMore: boolean;
  loading: boolean;
  threshold?: number;
}

export function InfiniteScroll({
  onLoadMore,
  hasMore,
  loading,
  threshold = 200,
}: InfiniteScrollProps) {
  const sentinelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || !hasMore) return;

    const observer = new IntersectionObserver(
      (entries) => {
        const entry = entries[0];
        if (entry.isIntersecting && !loading && hasMore) {
          onLoadMore();
        }
      },
      {
        rootMargin: `${threshold}px`,
      },
    );

    observer.observe(sentinel);

    return () => {
      observer.disconnect();
    };
  }, [onLoadMore, hasMore, loading, threshold]);

  return (
    <div ref={sentinelRef} className="w-full py-4">
      {loading && (
        <div className="flex justify-center gap-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="w-[180px]">
              <Skeleton className="aspect-[3/4] w-full rounded-lg" />
              <Skeleton className="h-4 w-3/4 mt-2 rounded" />
            </div>
          ))}
        </div>
      )}
      {!hasMore && !loading && (
        <p className="text-center text-sm text-[var(--color-text-muted)]">
          You have reached the end
        </p>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/common/InfiniteScroll.tsx
git commit -m "feat(web): add InfiniteScroll component with intersection observer"
```

---

### Task 10: Create AnimeHero Component

**Files:**
- Create: `web/components/anime/AnimeHero.tsx`

- [ ] **Step 1: Create `web/components/anime/AnimeHero.tsx`**

```tsx
"use client";

import Image from "next/image";
import { cn } from "@/lib/utils";
import type { Anime } from "@/types/anime";
import { useSource } from "@/contexts/SourceContext";

interface AnimeHeroProps {
  anime: Anime;
  isInWatchlist: boolean;
  onToggleWatchlist: () => void;
  className?: string;
}

export function AnimeHero({
  anime,
  isInWatchlist,
  onToggleWatchlist,
  className,
}: AnimeHeroProps) {
  const { activeSource } = useSource();

  return (
    <div className={cn("relative w-full", className)}>
      {/* Banner */}
      <div className="relative w-full h-[300px] sm:h-[350px] md:h-[400px]">
        {anime.bannerImage || anime.coverUrl ? (
          <Image
            src={anime.bannerImage || anime.coverUrl || ""}
            alt={anime.title}
            fill
            priority
            sizes="100vw"
            className="object-cover"
          />
        ) : (
          <div className="w-full h-full bg-gradient-to-r from-[var(--color-surface)] to-[var(--color-bg)]" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-[var(--color-bg)] via-[var(--color-bg)]/60 to-transparent" />
      </div>

      {/* Content overlay */}
      <div className="relative -mt-32 sm:-mt-40 px-4 sm:px-6 md:px-8 flex flex-col sm:flex-row gap-6 items-start">
        {/* Poster */}
        <div className="relative w-[150px] sm:w-[180px] md:w-[200px] aspect-[3/4] rounded-lg overflow-hidden shadow-2xl shadow-black/50 flex-shrink-0 border-2 border-[var(--color-surface)]">
          {anime.coverUrl ? (
            <Image
              src={anime.coverUrl}
              alt={anime.title}
              fill
              sizes="200px"
              className="object-cover"
            />
          ) : (
            <div className="w-full h-full bg-[var(--color-surface)] flex items-center justify-center">
              <svg
                className="w-12 h-12 text-[var(--color-text-muted)]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={1.5}
                  d="M15.75 10.5l4.72-4.72a.75.75 0 011.28.53v11.38a.75.75 0 01-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 002.25-2.25v-9a2.25 2.25 0 00-2.25-2.25h-9A2.25 2.25 0 002.25 7.5v9a2.25 2.25 0 002.25 2.25z"
                />
              </svg>
            </div>
          )}
        </div>

        {/* Metadata */}
        <div className="flex-1 space-y-3 pt-2">
          <h1 className="text-2xl sm:text-3xl md:text-4xl font-bold text-[var(--color-text)]">
            {anime.title}
          </h1>

          {anime.titleJapanese && (
            <p className="text-sm text-[var(--color-text-muted)]">
              {anime.titleJapanese}
            </p>
          )}

          {/* Meta badges */}
          <div className="flex flex-wrap items-center gap-3 text-sm">
            <span className="px-3 py-1 rounded-full bg-[var(--color-primary)]/20 text-[var(--color-primary)] font-semibold capitalize">
              {anime.status}
            </span>
            {anime.rating > 0 && (
              <span className="flex items-center gap-1 text-yellow-400 font-semibold">
                <svg
                  className="w-4 h-4"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                >
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                {anime.rating.toFixed(1)}
              </span>
            )}
            {anime.releaseYear && (
              <span className="text-[var(--color-text-muted)]">
                {anime.releaseYear}
              </span>
            )}
            {anime.totalEpisodes > 0 && (
              <span className="text-[var(--color-text-muted)]">
                {anime.totalEpisodes} episodes
              </span>
            )}
            {anime.duration && (
              <span className="text-[var(--color-text-muted)]">
                {anime.duration}
              </span>
            )}
            {anime.type && (
              <span className="text-[var(--color-text-muted)] uppercase">
                {anime.type}
              </span>
            )}
          </div>

          {/* Genres */}
          {anime.genres && anime.genres.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {anime.genres.map((genre) => (
                <span
                  key={genre}
                  className="text-xs px-2.5 py-1 rounded-full bg-[var(--color-surface)] text-[var(--color-text-muted)] border border-[var(--color-border)]"
                >
                  {genre}
                </span>
              ))}
            </div>
          )}

          {/* Studios */}
          {anime.studios && anime.studios.length > 0 && (
            <p className="text-sm text-[var(--color-text-muted)]">
              <span className="font-medium text-[var(--color-text)]">Studio: </span>
              {anime.studios.join(", ")}
            </p>
          )}

          {/* Synopsis */}
          {(anime.synopsis || anime.description) && (
            <p className="text-sm text-[var(--color-text-muted)] leading-relaxed line-clamp-4 max-w-3xl">
              {anime.synopsis || anime.description}
            </p>
          )}

          {/* Actions */}
          <div className="flex items-center gap-3 pt-2">
            <button
              onClick={onToggleWatchlist}
              className={cn(
                "inline-flex items-center gap-2 px-5 py-2.5 rounded-lg font-semibold text-sm transition-colors",
                isInWatchlist
                  ? "bg-[var(--color-primary)] text-white"
                  : "bg-[var(--color-surface)] text-[var(--color-text)] border border-[var(--color-border)] hover:bg-[var(--color-surface-hover)]",
              )}
            >
              <svg
                className="w-5 h-5"
                fill={isInWatchlist ? "currentColor" : "none"}
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"
                />
              </svg>
              {isInWatchlist ? "In Watchlist" : "Add to Watchlist"}
            </button>

            {/* Source Badge */}
            {activeSource && (
              <span className="px-3 py-2 text-xs font-medium rounded-lg bg-[var(--color-surface)] text-[var(--color-text-muted)] border border-[var(--color-border)]">
                Source: {activeSource.name}
              </span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/anime/AnimeHero.tsx
git commit -m "feat(web): add AnimeHero component with banner, poster, metadata, watchlist button"
```

---

### Task 11: Create EpisodeCard and EpisodeList

**Files:**
- Create: `web/components/anime/EpisodeCard.tsx`
- Create: `web/components/anime/EpisodeList.tsx`

- [ ] **Step 1: Create `web/components/anime/EpisodeCard.tsx`**

```tsx
"use client";

import Link from "next/link";
import Image from "next/image";
import { cn } from "@/lib/utils";
import { formatDuration } from "@/lib/utils";
import type { Episode } from "@/types/anime";

interface EpisodeCardProps {
  episode: Episode;
  animeId: string;
  isActive?: boolean;
  progressSeconds?: number;
  className?: string;
}

export function EpisodeCard({
  episode,
  animeId,
  isActive = false,
  progressSeconds,
  className,
}: EpisodeCardProps) {
  const progressPercent =
    progressSeconds && episode.duration > 0
      ? Math.min((progressSeconds / episode.duration) * 100, 100)
      : 0;

  return (
    <Link
      href={`/anime/${animeId}/player/${episode.id}`}
      className={cn(
        "group flex gap-3 p-3 rounded-lg transition-colors",
        isActive
          ? "bg-[var(--color-primary)]/10 border border-[var(--color-primary)]/30"
          : "bg-[var(--color-surface)] hover:bg-[var(--color-surface-hover)]",
        className,
      )}
    >
      {/* Thumbnail */}
      <div className="relative w-[120px] sm:w-[160px] aspect-video rounded-md overflow-hidden flex-shrink-0">
        {episode.thumbnail ? (
          <Image
            src={episode.thumbnail}
            alt={`Episode ${episode.number}`}
            fill
            sizes="160px"
            className="object-cover"
          />
        ) : (
          <div className="w-full h-full bg-[var(--color-border)] flex items-center justify-center">
            <svg
              className="w-8 h-8 text-[var(--color-text-muted)]"
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path
                fillRule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z"
                clipRule="evenodd"
              />
            </svg>
          </div>
        )}

        {/* Play overlay on hover */}
        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors flex items-center justify-center">
          <svg
            className="w-10 h-10 text-white opacity-0 group-hover:opacity-100 transition-opacity"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fillRule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z"
              clipRule="evenodd"
            />
          </svg>
        </div>

        {/* Progress bar */}
        {progressPercent > 0 && (
          <div className="absolute bottom-0 left-0 right-0 h-1 bg-black/50">
            <div
              className="h-full bg-[var(--color-primary)]"
              style={{ width: `${progressPercent}%` }}
            />
          </div>
        )}
      </div>

      {/* Info */}
      <div className="flex flex-col justify-center min-w-0 flex-1">
        <p className="text-xs text-[var(--color-text-muted)] mb-0.5">
          Episode {episode.number}
        </p>
        <h4 className="text-sm font-medium text-[var(--color-text)] line-clamp-2">
          {episode.title || `Episode ${episode.number}`}
        </h4>
        {episode.duration > 0 && (
          <p className="text-xs text-[var(--color-text-muted)] mt-1">
            {formatDuration(episode.duration)}
          </p>
        )}
        {episode.source && (
          <p className="text-[10px] text-[var(--color-text-muted)] mt-1 uppercase">
            {episode.source}
          </p>
        )}
      </div>
    </Link>
  );
}
```

- [ ] **Step 2: Create `web/components/anime/EpisodeList.tsx`**

```tsx
"use client";

import { useState } from "react";
import { cn } from "@/lib/utils";
import type { Episode } from "@/types/anime";
import { EpisodeCard } from "./EpisodeCard";

interface EpisodeListProps {
  episodes: Episode[];
  animeId: string;
  activeEpisodeId?: string;
  progressMap?: Record<string, number>;
  className?: string;
}

export function EpisodeList({
  episodes,
  animeId,
  activeEpisodeId,
  progressMap = {},
  className,
}: EpisodeListProps) {
  const [sortAsc, setSortAsc] = useState(true);

  const sorted = [...episodes].sort((a, b) =>
    sortAsc ? a.number - b.number : b.number - a.number,
  );

  return (
    <div className={cn("space-y-4", className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-bold text-[var(--color-text)]">
          Episodes ({episodes.length})
        </h3>
        <button
          onClick={() => setSortAsc((prev) => !prev)}
          className="flex items-center gap-1.5 text-sm text-[var(--color-text-muted)] hover:text-[var(--color-text)] transition-colors"
        >
          <svg
            className={cn(
              "w-4 h-4 transition-transform",
              !sortAsc && "rotate-180",
            )}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M3 4h13M3 8h9m-9 4h6m4 0l4-4m0 0l4 4m-4-4v12"
            />
          </svg>
          {sortAsc ? "Oldest first" : "Newest first"}
        </button>
      </div>

      {/* Episode grid */}
      {episodes.length === 0 ? (
        <p className="text-sm text-[var(--color-text-muted)] py-8 text-center">
          No episodes available yet
        </p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {sorted.map((episode) => (
            <EpisodeCard
              key={episode.id}
              episode={episode}
              animeId={animeId}
              isActive={episode.id === activeEpisodeId}
              progressSeconds={progressMap[episode.id]}
            />
          ))}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add web/components/anime/EpisodeCard.tsx web/components/anime/EpisodeList.tsx
git commit -m "feat(web): add EpisodeCard and EpisodeList components with progress bars"
```

---

### Task 12: Create Anime Detail Page

**Files:**
- Create: `web/app/(main)/anime/[id]/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/anime/[id]/page.tsx`**

```tsx
"use client";

import { useState, useEffect, use } from "react";
import { useRouter } from "next/navigation";
import type { Anime, Episode } from "@/types/anime";
import { animeService } from "@/services/anime.service";
import { apiClient } from "@/services/api-client";
import { AnimeHero } from "@/components/anime/AnimeHero";
import { EpisodeList } from "@/components/anime/EpisodeList";
import { Skeleton } from "@/components/ui/Skeleton";
import { useAuth } from "@/contexts/AuthContext";

interface WatchHistory {
  episodeId: string;
  progressSeconds: number;
}

export default function AnimeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const router = useRouter();
  const { user } = useAuth();

  const [anime, setAnime] = useState<Anime | null>(null);
  const [episodes, setEpisodes] = useState<Episode[]>([]);
  const [loading, setLoading] = useState(true);
  const [isInWatchlist, setIsInWatchlist] = useState(false);
  const [progressMap, setProgressMap] = useState<Record<string, number>>({});

  // Load anime data
  useEffect(() => {
    setLoading(true);

    Promise.all([
      animeService.getAnimeById(id),
      animeService.getEpisodes(id),
    ])
      .then(([animeData, episodeData]) => {
        setAnime(animeData);
        setEpisodes(episodeData);
      })
      .catch(() => {
        router.push("/anime");
      })
      .finally(() => setLoading(false));
  }, [id, router]);

  // Check watchlist status + load progress
  useEffect(() => {
    if (!user || !id) return;

    apiClient
      .get<{ inWatchlist: boolean }>(`/users/watchlist/${id}/check`)
      .then((res) => setIsInWatchlist(res.inWatchlist))
      .catch(() => {});

    apiClient
      .get<WatchHistory[]>(`/users/anime/${id}/progress`)
      .then((data) => {
        const map: Record<string, number> = {};
        data.forEach((h) => {
          map[h.episodeId] = h.progressSeconds;
        });
        setProgressMap(map);
      })
      .catch(() => {});
  }, [user, id]);

  const toggleWatchlist = async () => {
    if (!user) {
      router.push("/login");
      return;
    }

    try {
      if (isInWatchlist) {
        await apiClient.delete(`/users/watchlist/${id}`);
        setIsInWatchlist(false);
      } else {
        await apiClient.post(`/users/watchlist/${id}`);
        setIsInWatchlist(true);
      }
    } catch {
      // Silently fail
    }
  };

  if (loading) {
    return (
      <div className="space-y-6">
        <Skeleton className="w-full h-[400px] rounded-xl" />
        <div className="px-4 space-y-4">
          <Skeleton className="h-8 w-1/2" />
          <Skeleton className="h-4 w-3/4" />
          <Skeleton className="h-4 w-2/3" />
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-6">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton key={i} className="h-24 rounded-lg" />
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (!anime) return null;

  return (
    <div className="space-y-8 pb-10">
      <AnimeHero
        anime={anime}
        isInWatchlist={isInWatchlist}
        onToggleWatchlist={toggleWatchlist}
      />

      <div className="px-4 sm:px-6 md:px-8">
        <EpisodeList
          episodes={episodes}
          animeId={id}
          progressMap={progressMap}
        />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/anime/\[id\]/page.tsx
git commit -m "feat(web): add anime detail page with hero, episodes, watchlist, progress"
```

---

### Task 13: Create VideoPlayer Component

**Files:**
- Create: `web/components/player/VideoPlayer.tsx`

- [ ] **Step 1: Create `web/components/player/VideoPlayer.tsx`**

```tsx
"use client";

import { useRef, useEffect, useState, useCallback } from "react";
import Hls from "hls.js";
import { PlayerControls } from "./PlayerControls";

interface VideoPlayerProps {
  src: string;
  poster?: string;
  autoPlay?: boolean;
  startTime?: number;
  onTimeUpdate?: (currentTime: number, duration: number) => void;
  onEnded?: () => void;
  className?: string;
}

export function VideoPlayer({
  src,
  poster,
  autoPlay = false,
  startTime = 0,
  onTimeUpdate,
  onEnded,
  className,
}: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const hlsRef = useRef<Hls | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);
  const [isMuted, setIsMuted] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [playbackRate, setPlaybackRate] = useState(1);
  const [isBuffering, setIsBuffering] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const hideControlsTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const isHls = src.includes(".m3u8");

  // Initialize player
  useEffect(() => {
    const video = videoRef.current;
    if (!video || !src) return;

    // Destroy previous HLS instance
    if (hlsRef.current) {
      hlsRef.current.destroy();
      hlsRef.current = null;
    }

    if (isHls) {
      if (Hls.isSupported()) {
        const hls = new Hls({
          enableWorker: true,
          lowLatencyMode: true,
          backBufferLength: 90,
        });
        hlsRef.current = hls;
        hls.loadSource(src);
        hls.attachMedia(video);

        hls.on(Hls.Events.MANIFEST_PARSED, () => {
          if (startTime > 0) {
            video.currentTime = startTime;
          }
          if (autoPlay) {
            video.play().catch(() => {});
          }
        });

        hls.on(Hls.Events.ERROR, (_event, data) => {
          if (data.fatal) {
            switch (data.type) {
              case Hls.ErrorTypes.NETWORK_ERROR:
                hls.startLoad();
                break;
              case Hls.ErrorTypes.MEDIA_ERROR:
                hls.recoverMediaError();
                break;
              default:
                hls.destroy();
                break;
            }
          }
        });
      } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
        // Safari native HLS
        video.src = src;
        if (startTime > 0) {
          video.currentTime = startTime;
        }
        if (autoPlay) {
          video.play().catch(() => {});
        }
      }
    } else {
      // Direct MP4
      video.src = src;
      video.load();
      if (startTime > 0) {
        video.currentTime = startTime;
      }
      if (autoPlay) {
        video.play().catch(() => {});
      }
    }

    return () => {
      if (hlsRef.current) {
        hlsRef.current.destroy();
        hlsRef.current = null;
      }
    };
  }, [src, autoPlay, startTime, isHls]);

  // Event handlers
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const handlePlay = () => setIsPlaying(true);
    const handlePause = () => setIsPlaying(false);
    const handleTimeUpdate = () => {
      setCurrentTime(video.currentTime);
      onTimeUpdate?.(video.currentTime, video.duration);
    };
    const handleDurationChange = () => setDuration(video.duration);
    const handleEnded = () => {
      setIsPlaying(false);
      onEnded?.();
    };
    const handleWaiting = () => setIsBuffering(true);
    const handleCanPlay = () => setIsBuffering(false);
    const handleVolumeChange = () => {
      setVolume(video.volume);
      setIsMuted(video.muted);
    };

    video.addEventListener("play", handlePlay);
    video.addEventListener("pause", handlePause);
    video.addEventListener("timeupdate", handleTimeUpdate);
    video.addEventListener("durationchange", handleDurationChange);
    video.addEventListener("ended", handleEnded);
    video.addEventListener("waiting", handleWaiting);
    video.addEventListener("canplay", handleCanPlay);
    video.addEventListener("volumechange", handleVolumeChange);

    return () => {
      video.removeEventListener("play", handlePlay);
      video.removeEventListener("pause", handlePause);
      video.removeEventListener("timeupdate", handleTimeUpdate);
      video.removeEventListener("durationchange", handleDurationChange);
      video.removeEventListener("ended", handleEnded);
      video.removeEventListener("waiting", handleWaiting);
      video.removeEventListener("canplay", handleCanPlay);
      video.removeEventListener("volumechange", handleVolumeChange);
    };
  }, [onTimeUpdate, onEnded]);

  // Fullscreen detection
  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener("fullscreenchange", handleFullscreenChange);
    return () => {
      document.removeEventListener("fullscreenchange", handleFullscreenChange);
    };
  }, []);

  // Auto-hide controls
  const resetHideTimer = useCallback(() => {
    setShowControls(true);
    if (hideControlsTimer.current) {
      clearTimeout(hideControlsTimer.current);
    }
    if (isPlaying) {
      hideControlsTimer.current = setTimeout(() => {
        setShowControls(false);
      }, 3000);
    }
  }, [isPlaying]);

  useEffect(() => {
    resetHideTimer();
    return () => {
      if (hideControlsTimer.current) {
        clearTimeout(hideControlsTimer.current);
      }
    };
  }, [isPlaying, resetHideTimer]);

  // Player controls
  const togglePlay = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    if (video.paused) {
      video.play().catch(() => {});
    } else {
      video.pause();
    }
  }, []);

  const seek = useCallback((time: number) => {
    const video = videoRef.current;
    if (!video) return;
    video.currentTime = Math.max(0, Math.min(time, video.duration || 0));
  }, []);

  const changeVolume = useCallback((vol: number) => {
    const video = videoRef.current;
    if (!video) return;
    video.volume = Math.max(0, Math.min(1, vol));
    video.muted = vol === 0;
  }, []);

  const toggleMute = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    video.muted = !video.muted;
  }, []);

  const toggleFullscreen = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;
    if (document.fullscreenElement) {
      document.exitFullscreen();
    } else {
      container.requestFullscreen();
    }
  }, []);

  const changePlaybackRate = useCallback((rate: number) => {
    const video = videoRef.current;
    if (!video) return;
    video.playbackRate = rate;
    setPlaybackRate(rate);
  }, []);

  return (
    <div
      ref={containerRef}
      className={`relative bg-black group ${className || ""}`}
      onMouseMove={resetHideTimer}
      onClick={togglePlay}
    >
      <video
        ref={videoRef}
        poster={poster}
        playsInline
        className="w-full h-full object-contain"
      />

      {/* Buffering spinner */}
      {isBuffering && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div className="w-12 h-12 border-4 border-white/30 border-t-white rounded-full animate-spin" />
        </div>
      )}

      {/* Controls */}
      <div
        className={`absolute inset-x-0 bottom-0 transition-opacity duration-300 ${
          showControls ? "opacity-100" : "opacity-0"
        }`}
        onClick={(e) => e.stopPropagation()}
      >
        <PlayerControls
          isPlaying={isPlaying}
          currentTime={currentTime}
          duration={duration}
          volume={volume}
          isMuted={isMuted}
          isFullscreen={isFullscreen}
          playbackRate={playbackRate}
          onTogglePlay={togglePlay}
          onSeek={seek}
          onVolumeChange={changeVolume}
          onToggleMute={toggleMute}
          onToggleFullscreen={toggleFullscreen}
          onPlaybackRateChange={changePlaybackRate}
        />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/player/VideoPlayer.tsx
git commit -m "feat(web): add VideoPlayer with hls.js integration, HLS + MP4 support"
```

---

### Task 14: Create PlayerControls Component

**Files:**
- Create: `web/components/player/PlayerControls.tsx`

- [ ] **Step 1: Create `web/components/player/PlayerControls.tsx`**

```tsx
"use client";

import { useState, useRef, useCallback } from "react";
import { formatDuration } from "@/lib/utils";

interface PlayerControlsProps {
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  volume: number;
  isMuted: boolean;
  isFullscreen: boolean;
  playbackRate: number;
  onTogglePlay: () => void;
  onSeek: (time: number) => void;
  onVolumeChange: (volume: number) => void;
  onToggleMute: () => void;
  onToggleFullscreen: () => void;
  onPlaybackRateChange: (rate: number) => void;
}

const PLAYBACK_RATES = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];

export function PlayerControls({
  isPlaying,
  currentTime,
  duration,
  volume,
  isMuted,
  isFullscreen,
  playbackRate,
  onTogglePlay,
  onSeek,
  onVolumeChange,
  onToggleMute,
  onToggleFullscreen,
  onPlaybackRateChange,
}: PlayerControlsProps) {
  const seekBarRef = useRef<HTMLDivElement>(null);
  const [showSpeedMenu, setShowSpeedMenu] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [hoverTime, setHoverTime] = useState<number | null>(null);
  const [hoverX, setHoverX] = useState(0);

  const progress = duration > 0 ? (currentTime / duration) * 100 : 0;

  const handleSeekBarClick = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      const bar = seekBarRef.current;
      if (!bar || duration <= 0) return;
      const rect = bar.getBoundingClientRect();
      const fraction = Math.max(
        0,
        Math.min(1, (e.clientX - rect.left) / rect.width),
      );
      onSeek(fraction * duration);
    },
    [duration, onSeek],
  );

  const handleSeekBarMouseMove = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      const bar = seekBarRef.current;
      if (!bar || duration <= 0) return;
      const rect = bar.getBoundingClientRect();
      const fraction = Math.max(
        0,
        Math.min(1, (e.clientX - rect.left) / rect.width),
      );
      setHoverTime(fraction * duration);
      setHoverX(e.clientX - rect.left);
    },
    [duration],
  );

  const handleSeekBarMouseDown = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      setIsDragging(true);
      handleSeekBarClick(e);

      const handleMouseMove = (ev: MouseEvent) => {
        const bar = seekBarRef.current;
        if (!bar || duration <= 0) return;
        const rect = bar.getBoundingClientRect();
        const fraction = Math.max(
          0,
          Math.min(1, (ev.clientX - rect.left) / rect.width),
        );
        onSeek(fraction * duration);
      };

      const handleMouseUp = () => {
        setIsDragging(false);
        document.removeEventListener("mousemove", handleMouseMove);
        document.removeEventListener("mouseup", handleMouseUp);
      };

      document.addEventListener("mousemove", handleMouseMove);
      document.addEventListener("mouseup", handleMouseUp);
    },
    [duration, handleSeekBarClick, onSeek],
  );

  const effectiveVolume = isMuted ? 0 : volume;

  return (
    <div className="bg-gradient-to-t from-black/90 via-black/60 to-transparent pt-12 pb-3 px-4">
      {/* Seek bar */}
      <div
        ref={seekBarRef}
        className="relative h-6 flex items-center cursor-pointer group/seek mb-2"
        onClick={handleSeekBarClick}
        onMouseMove={handleSeekBarMouseMove}
        onMouseLeave={() => setHoverTime(null)}
        onMouseDown={handleSeekBarMouseDown}
      >
        {/* Track */}
        <div className="w-full h-1 group-hover/seek:h-1.5 rounded-full bg-white/20 transition-all relative">
          {/* Buffer bar (placeholder) */}
          <div
            className="absolute inset-y-0 left-0 bg-white/30 rounded-full"
            style={{ width: `${Math.min(progress + 5, 100)}%` }}
          />
          {/* Progress */}
          <div
            className="absolute inset-y-0 left-0 bg-[var(--color-primary)] rounded-full"
            style={{ width: `${progress}%` }}
          />
          {/* Thumb */}
          <div
            className="absolute top-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-[var(--color-primary)] opacity-0 group-hover/seek:opacity-100 transition-opacity shadow"
            style={{ left: `${progress}%`, transform: "translate(-50%, -50%)" }}
          />
        </div>

        {/* Hover time tooltip */}
        {hoverTime !== null && (
          <div
            className="absolute -top-8 bg-black/80 text-white text-xs px-2 py-1 rounded pointer-events-none"
            style={{
              left: `${hoverX}px`,
              transform: "translateX(-50%)",
            }}
          >
            {formatDuration(Math.floor(hoverTime))}
          </div>
        )}
      </div>

      {/* Controls row */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          {/* Play/Pause */}
          <button
            onClick={onTogglePlay}
            className="text-white hover:text-[var(--color-primary)] transition-colors"
            aria-label={isPlaying ? "Pause" : "Play"}
          >
            {isPlaying ? (
              <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
                <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
              </svg>
            ) : (
              <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
            )}
          </button>

          {/* Volume */}
          <div className="flex items-center gap-2 group/vol">
            <button
              onClick={onToggleMute}
              className="text-white hover:text-[var(--color-primary)] transition-colors"
              aria-label={isMuted ? "Unmute" : "Mute"}
            >
              {effectiveVolume === 0 ? (
                <svg
                  className="w-5 h-5"
                  fill="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51A8.796 8.796 0 0021 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06a8.99 8.99 0 003.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z" />
                </svg>
              ) : effectiveVolume < 0.5 ? (
                <svg
                  className="w-5 h-5"
                  fill="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path d="M18.5 12c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM5 9v6h4l5 5V4L9 9H5z" />
                </svg>
              ) : (
                <svg
                  className="w-5 h-5"
                  fill="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" />
                </svg>
              )}
            </button>
            <input
              type="range"
              min="0"
              max="1"
              step="0.05"
              value={effectiveVolume}
              onChange={(e) => onVolumeChange(parseFloat(e.target.value))}
              className="w-0 group-hover/vol:w-20 transition-all duration-200 accent-[var(--color-primary)] cursor-pointer"
              aria-label="Volume"
            />
          </div>

          {/* Time */}
          <span className="text-xs text-white/70 font-mono min-w-[80px]">
            {formatDuration(Math.floor(currentTime))} /{" "}
            {formatDuration(Math.floor(duration))}
          </span>
        </div>

        <div className="flex items-center gap-3">
          {/* Playback Speed */}
          <div className="relative">
            <button
              onClick={() => setShowSpeedMenu((prev) => !prev)}
              className="text-xs text-white hover:text-[var(--color-primary)] font-semibold transition-colors px-2 py-1"
              aria-label="Playback speed"
            >
              {playbackRate}x
            </button>
            {showSpeedMenu && (
              <div className="absolute bottom-full right-0 mb-2 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg shadow-xl py-1 min-w-[80px]">
                {PLAYBACK_RATES.map((rate) => (
                  <button
                    key={rate}
                    onClick={() => {
                      onPlaybackRateChange(rate);
                      setShowSpeedMenu(false);
                    }}
                    className={`w-full text-left px-3 py-1.5 text-sm transition-colors ${
                      rate === playbackRate
                        ? "text-[var(--color-primary)] bg-[var(--color-primary)]/10"
                        : "text-[var(--color-text)] hover:bg-[var(--color-surface-hover)]"
                    }`}
                  >
                    {rate}x
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Fullscreen */}
          <button
            onClick={onToggleFullscreen}
            className="text-white hover:text-[var(--color-primary)] transition-colors"
            aria-label={isFullscreen ? "Exit fullscreen" : "Enter fullscreen"}
          >
            {isFullscreen ? (
              <svg
                className="w-5 h-5"
                fill="currentColor"
                viewBox="0 0 24 24"
              >
                <path d="M5 16h3v3h2v-5H5v2zm3-8H5v2h5V5H8v3zm6 11h2v-3h3v-2h-5v5zm2-11V5h-2v5h5V8h-3z" />
              </svg>
            ) : (
              <svg
                className="w-5 h-5"
                fill="currentColor"
                viewBox="0 0 24 24"
              >
                <path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z" />
              </svg>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/player/PlayerControls.tsx
git commit -m "feat(web): add PlayerControls with seek, volume, playback speed, fullscreen"
```

---

### Task 15: Create EpisodeSidebar Component

**Files:**
- Create: `web/components/player/EpisodeSidebar.tsx`

- [ ] **Step 1: Create `web/components/player/EpisodeSidebar.tsx`**

```tsx
"use client";

import { useRef, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";
import { cn } from "@/lib/utils";
import type { Episode } from "@/types/anime";

interface EpisodeSidebarProps {
  episodes: Episode[];
  animeId: string;
  currentEpisodeId: string;
  animeName?: string;
  className?: string;
}

export function EpisodeSidebar({
  episodes,
  animeId,
  currentEpisodeId,
  animeName,
  className,
}: EpisodeSidebarProps) {
  const activeRef = useRef<HTMLAnchorElement>(null);

  // Scroll to active episode on mount
  useEffect(() => {
    if (activeRef.current) {
      activeRef.current.scrollIntoView({
        behavior: "smooth",
        block: "center",
      });
    }
  }, [currentEpisodeId]);

  const sorted = [...episodes].sort((a, b) => a.number - b.number);

  return (
    <div
      className={cn(
        "flex flex-col bg-[var(--color-surface)] border-l border-[var(--color-border)] h-full",
        className,
      )}
    >
      {/* Header */}
      <div className="p-4 border-b border-[var(--color-border)]">
        <h3 className="font-bold text-[var(--color-text)] text-sm truncate">
          {animeName || "Episodes"}
        </h3>
        <p className="text-xs text-[var(--color-text-muted)] mt-0.5">
          {episodes.length} episodes
        </p>
      </div>

      {/* Episode list */}
      <div className="flex-1 overflow-y-auto">
        {sorted.map((episode) => {
          const isActive = episode.id === currentEpisodeId;

          return (
            <Link
              key={episode.id}
              ref={isActive ? activeRef : undefined}
              href={`/anime/${animeId}/player/${episode.id}`}
              className={cn(
                "flex items-center gap-3 px-4 py-3 transition-colors border-l-2",
                isActive
                  ? "bg-[var(--color-primary)]/10 border-l-[var(--color-primary)] text-[var(--color-text)]"
                  : "border-l-transparent hover:bg-[var(--color-surface-hover)] text-[var(--color-text-muted)]",
              )}
            >
              {/* Thumbnail */}
              <div className="relative w-[80px] aspect-video rounded overflow-hidden flex-shrink-0">
                {episode.thumbnail ? (
                  <Image
                    src={episode.thumbnail}
                    alt={`Ep ${episode.number}`}
                    fill
                    sizes="80px"
                    className="object-cover"
                  />
                ) : (
                  <div className="w-full h-full bg-[var(--color-border)] flex items-center justify-center">
                    <span className="text-xs font-bold">
                      {episode.number}
                    </span>
                  </div>
                )}
                {isActive && (
                  <div className="absolute inset-0 bg-black/40 flex items-center justify-center">
                    <div className="flex gap-0.5">
                      <span className="w-1 h-3 bg-white rounded-full animate-pulse" />
                      <span className="w-1 h-3 bg-white rounded-full animate-pulse [animation-delay:150ms]" />
                      <span className="w-1 h-3 bg-white rounded-full animate-pulse [animation-delay:300ms]" />
                    </div>
                  </div>
                )}
              </div>

              {/* Info */}
              <div className="min-w-0 flex-1">
                <p className="text-xs font-medium">
                  Ep {episode.number}
                </p>
                <p className="text-xs truncate mt-0.5">
                  {episode.title || `Episode ${episode.number}`}
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/player/EpisodeSidebar.tsx
git commit -m "feat(web): add EpisodeSidebar with auto-scroll to current episode"
```

---

### Task 16: Create Player Page

**Files:**
- Create: `web/app/(main)/anime/[id]/player/[episodeId]/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/anime/[id]/player/[episodeId]/page.tsx`**

```tsx
"use client";

import { useState, useEffect, useRef, useCallback, use } from "react";
import { useRouter } from "next/navigation";
import type { Anime, Episode } from "@/types/anime";
import { animeService } from "@/services/anime.service";
import { apiClient } from "@/services/api-client";
import { VideoPlayer } from "@/components/player/VideoPlayer";
import { EpisodeSidebar } from "@/components/player/EpisodeSidebar";
import { Skeleton } from "@/components/ui/Skeleton";
import { useAuth } from "@/contexts/AuthContext";

interface EpisodeProgress {
  progressSeconds: number;
  completed: boolean;
}

export default function PlayerPage({
  params,
}: {
  params: Promise<{ id: string; episodeId: string }>;
}) {
  const { id, episodeId } = use(params);
  const router = useRouter();
  const { user } = useAuth();

  const [anime, setAnime] = useState<Anime | null>(null);
  const [episodes, setEpisodes] = useState<Episode[]>([]);
  const [currentEpisode, setCurrentEpisode] = useState<Episode | null>(null);
  const [loading, setLoading] = useState(true);
  const [startTime, setStartTime] = useState(0);

  const lastProgressSave = useRef<number>(0);
  const progressIntervalRef = useRef<ReturnType<typeof setInterval> | null>(
    null,
  );
  const currentTimeRef = useRef<number>(0);
  const durationRef = useRef<number>(0);

  // Load anime + episodes + progress
  useEffect(() => {
    setLoading(true);

    Promise.all([
      animeService.getAnimeById(id),
      animeService.getEpisodes(id),
    ])
      .then(([animeData, episodeData]) => {
        setAnime(animeData);
        setEpisodes(episodeData);
        const episode = episodeData.find((e) => e.id === episodeId);
        setCurrentEpisode(episode || null);
      })
      .catch(() => {
        router.push(`/anime/${id}`);
      })
      .finally(() => setLoading(false));
  }, [id, episodeId, router]);

  // Load saved progress
  useEffect(() => {
    if (!user || !episodeId) return;

    apiClient
      .get<EpisodeProgress>(`/users/progress/${episodeId}`)
      .then((data) => {
        if (data && data.progressSeconds > 0 && !data.completed) {
          setStartTime(data.progressSeconds);
        }
      })
      .catch(() => {});
  }, [user, episodeId]);

  // Progress tracking: save every 10 seconds
  const saveProgress = useCallback(async () => {
    if (!user || !episodeId) return;
    const currentTime = currentTimeRef.current;
    const duration = durationRef.current;

    if (currentTime <= 0 || duration <= 0) return;
    if (Math.abs(currentTime - lastProgressSave.current) < 5) return;

    lastProgressSave.current = currentTime;
    const completed = duration > 0 && currentTime / duration > 0.9;

    try {
      await apiClient.post("/users/progress", {
        episodeId,
        progressSeconds: Math.floor(currentTime),
        completed,
      });
    } catch {
      // Silently fail -- will retry in 10s
    }
  }, [user, episodeId]);

  // Start/stop the 10-second interval
  useEffect(() => {
    if (!user) return;

    progressIntervalRef.current = setInterval(saveProgress, 10000);

    return () => {
      if (progressIntervalRef.current) {
        clearInterval(progressIntervalRef.current);
      }
      // Save one final time on unmount
      saveProgress();
    };
  }, [user, saveProgress]);

  const handleTimeUpdate = useCallback(
    (currentTime: number, duration: number) => {
      currentTimeRef.current = currentTime;
      durationRef.current = duration;
    },
    [],
  );

  const handleEnded = useCallback(() => {
    // Save completion
    saveProgress();

    // Auto-navigate to next episode
    if (currentEpisode && episodes.length > 0) {
      const sorted = [...episodes].sort((a, b) => a.number - b.number);
      const currentIdx = sorted.findIndex((e) => e.id === currentEpisode.id);
      if (currentIdx >= 0 && currentIdx < sorted.length - 1) {
        const next = sorted[currentIdx + 1];
        router.push(`/anime/${id}/player/${next.id}`);
      }
    }
  }, [currentEpisode, episodes, id, router, saveProgress]);

  if (loading) {
    return (
      <div className="flex flex-col lg:flex-row h-[calc(100vh-64px)]">
        <div className="flex-1">
          <Skeleton className="w-full aspect-video" />
        </div>
        <div className="w-full lg:w-[350px]">
          <Skeleton className="w-full h-full min-h-[300px]" />
        </div>
      </div>
    );
  }

  if (!currentEpisode) {
    return (
      <div className="flex items-center justify-center h-[calc(100vh-64px)]">
        <div className="text-center space-y-4">
          <p className="text-lg text-[var(--color-text-muted)]">
            Episode not found
          </p>
          <button
            onClick={() => router.push(`/anime/${id}`)}
            className="text-sm text-[var(--color-primary)] hover:underline"
          >
            Back to anime
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col lg:flex-row h-[calc(100vh-64px)]">
      {/* Video Player Area */}
      <div className="flex-1 flex flex-col bg-black">
        <VideoPlayer
          src={currentEpisode.streamUrl}
          poster={currentEpisode.thumbnail}
          autoPlay
          startTime={startTime}
          onTimeUpdate={handleTimeUpdate}
          onEnded={handleEnded}
          className="w-full aspect-video lg:h-full"
        />

        {/* Episode info bar */}
        <div className="bg-[var(--color-surface)] px-4 py-3 border-t border-[var(--color-border)]">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-sm font-bold text-[var(--color-text)]">
                {anime?.title}
              </h2>
              <p className="text-xs text-[var(--color-text-muted)] mt-0.5">
                Episode {currentEpisode.number}
                {currentEpisode.title &&
                  currentEpisode.title !== `Episode ${currentEpisode.number}` &&
                  ` - ${currentEpisode.title}`}
              </p>
            </div>
            {currentEpisode.source && (
              <span className="text-[10px] px-2 py-1 rounded bg-[var(--color-bg)] text-[var(--color-text-muted)] uppercase">
                {currentEpisode.source}
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Episode Sidebar (desktop) / Episode list below (mobile) */}
      <div className="w-full lg:w-[350px] h-[400px] lg:h-full">
        <EpisodeSidebar
          episodes={episodes}
          animeId={id}
          currentEpisodeId={episodeId}
          animeName={anime?.title}
          className="h-full"
        />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/anime/\[id\]/player/\[episodeId\]/page.tsx
git commit -m "feat(web): add player page with video, episode sidebar, progress tracking every 10s"
```

---

### Task 17: Create Calendar Page

**Files:**
- Create: `web/app/(main)/calendar/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/calendar/page.tsx`**

```tsx
"use client";

import { useState, useEffect } from "react";
import type { Anime } from "@/types/anime";
import { animeService } from "@/services/anime.service";
import { AnimeCard } from "@/components/anime/AnimeCard";
import { Skeleton } from "@/components/ui/Skeleton";
import { cn } from "@/lib/utils";

const DAYS_OF_WEEK = [
  { label: "Monday", value: "monday" },
  { label: "Tuesday", value: "tuesday" },
  { label: "Wednesday", value: "wednesday" },
  { label: "Thursday", value: "thursday" },
  { label: "Friday", value: "friday" },
  { label: "Saturday", value: "saturday" },
  { label: "Sunday", value: "sunday" },
];

function getTodayDayValue(): string {
  const dayIndex = new Date().getDay();
  // getDay() returns 0=Sunday, 1=Monday, etc.
  const map: Record<number, string> = {
    0: "sunday",
    1: "monday",
    2: "tuesday",
    3: "wednesday",
    4: "thursday",
    5: "friday",
    6: "saturday",
  };
  return map[dayIndex];
}

export default function CalendarPage() {
  const [scheduleByDay, setScheduleByDay] = useState<
    Record<string, Anime[]>
  >({});
  const [loading, setLoading] = useState(true);
  const [selectedDay, setSelectedDay] = useState<string>(getTodayDayValue());

  useEffect(() => {
    setLoading(true);

    // Load schedule for all days
    const promises = DAYS_OF_WEEK.map(async (day) => {
      try {
        const data = await animeService.getSchedule(day.value);
        return { day: day.value, anime: data };
      } catch {
        return { day: day.value, anime: [] };
      }
    });

    Promise.all(promises)
      .then((results) => {
        const map: Record<string, Anime[]> = {};
        results.forEach((r) => {
          map[r.day] = r.anime;
        });
        setScheduleByDay(map);
      })
      .finally(() => setLoading(false));
  }, []);

  const todayValue = getTodayDayValue();

  return (
    <div className="space-y-6 pb-10">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-[var(--color-text)]">
          Airing Schedule
        </h1>
        <p className="text-sm text-[var(--color-text-muted)] mt-1">
          See what anime airs each day of the week
        </p>
      </div>

      {/* Day tabs */}
      <div className="flex gap-2 overflow-x-auto pb-2" style={{ scrollbarWidth: "none" }}>
        {DAYS_OF_WEEK.map((day) => (
          <button
            key={day.value}
            onClick={() => setSelectedDay(day.value)}
            className={cn(
              "px-4 py-2 text-sm font-medium rounded-lg whitespace-nowrap transition-colors flex-shrink-0",
              selectedDay === day.value
                ? "bg-[var(--color-primary)] text-white"
                : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]",
              day.value === todayValue &&
                selectedDay !== day.value &&
                "ring-1 ring-[var(--color-primary)]/50",
            )}
          >
            {day.label}
            {day.value === todayValue && (
              <span className="ml-1.5 text-[10px] opacity-70">(Today)</span>
            )}
          </button>
        ))}
      </div>

      {/* Schedule grid */}
      {loading ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
          {Array.from({ length: 12 }).map((_, i) => (
            <div key={i}>
              <Skeleton className="aspect-[3/4] w-full rounded-lg" />
              <Skeleton className="h-4 w-3/4 mt-2 rounded" />
              <Skeleton className="h-3 w-1/2 mt-1 rounded" />
            </div>
          ))}
        </div>
      ) : (
        <>
          {/* Selected day content */}
          {scheduleByDay[selectedDay] &&
          scheduleByDay[selectedDay].length > 0 ? (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
              {scheduleByDay[selectedDay].map((item) => (
                <AnimeCard key={item.id} anime={item} />
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-20 text-center">
              <svg
                className="w-16 h-16 text-[var(--color-text-muted)] mb-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={1.5}
                  d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"
                />
              </svg>
              <p className="text-lg text-[var(--color-text-muted)]">
                No anime scheduled for{" "}
                {DAYS_OF_WEEK.find((d) => d.value === selectedDay)?.label}
              </p>
            </div>
          )}
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/calendar/page.tsx
git commit -m "feat(web): add airing calendar page with day-of-week tabs"
```

---

### Task 18: Manual Smoke Test Checklist

- [ ] **Step 1: Start the development servers**

```bash
# Terminal 1 - Backend
cd backend
npm run start:dev

# Terminal 2 - Web
cd web
npm run dev
```

- [ ] **Step 2: Verify home page**

Open `http://localhost:3000/home` in a browser and check:

1. Featured carousel renders with banner images, auto-slides every 6 seconds, arrows work, dot indicators work
2. All 6 category sections render: New Releases, Top Rated, Popular, Currently Airing, Classics, Upcoming
3. Horizontal scroll works on each section (arrows on desktop, touch on mobile)
4. "See all" links navigate to `/anime` with correct query params
5. AnimeCard shows cover image, status badge, rating badge, title, genres, year, episode count

- [ ] **Step 3: Verify anime browse page**

Open `http://localhost:3000/anime` and check:

1. Grid renders with anime cards in responsive columns (2/3/4/5/6 cols at breakpoints)
2. Status filter pills work (All, Ongoing, Completed, Upcoming)
3. Genre filter pills load from API and filter correctly
4. URL updates with query params when filters change
5. Infinite scroll triggers when scrolling to bottom, loads more cards
6. "No anime found" state shows when no results match filters

- [ ] **Step 4: Verify anime detail page**

Navigate to any anime card and check:

1. Banner image with gradient overlay renders
2. Poster image renders with shadow
3. Title, Japanese title, status badge, rating, year, episode count, duration, type all show
4. Genres display as rounded pills
5. Studios display
6. Synopsis/description shows (line-clamped)
7. Watchlist button toggles (requires login)
8. Source badge shows current active source
9. Episode list renders with thumbnails, episode numbers, titles, durations
10. Sort toggle (oldest/newest) works
11. Progress bars show on episodes with saved progress

- [ ] **Step 5: Verify video player**

Click any episode to navigate to player page and check:

1. Video loads and auto-plays (HLS streams via hls.js, MP4 directly)
2. Play/pause button works
3. Seek bar shows progress, is clickable and draggable
4. Hover time tooltip appears on seek bar
5. Volume slider appears on hover, mute button works
6. Playback speed menu shows all rates (0.25x - 2x)
7. Fullscreen toggle works
8. Controls auto-hide after 3 seconds of inactivity, reappear on mouse move
9. Buffering spinner shows when buffering
10. Episode info bar shows anime name, episode number, title, source
11. Episode sidebar shows all episodes, current episode highlighted with playing indicator
12. Clicking a different episode in sidebar navigates to it
13. Auto-advance to next episode works when current episode ends

- [ ] **Step 6: Verify progress tracking**

1. Open browser DevTools Network tab
2. Play a video and observe `POST /users/progress` requests every ~10 seconds
3. Navigate away and come back -- video should resume from saved position
4. On anime detail page, episodes with progress show progress bars

- [ ] **Step 7: Verify source context**

1. Check that SourceProvider loads sources on app start
2. Active source badge appears on anime detail page
3. Source context is accessible across pages

- [ ] **Step 8: Verify calendar page**

Open `http://localhost:3000/calendar` and check:

1. Day-of-week tabs render, today is highlighted with ring and "(Today)" label
2. Default selected tab is today
3. Clicking a different day loads that day's schedule
4. Anime cards display in responsive grid for each day
5. Empty state shows when no anime scheduled for a day

- [ ] **Step 9: Verify responsive layout**

1. Test at mobile viewport (< 640px): single/two column grids, bottom nav, full-width player
2. Test at tablet viewport (768px-1023px): 2-4 column grids, player with episode list below
3. Test at desktop viewport (1024px+): 5-6 column grids, player with sidebar on right, persistent sidebar nav
