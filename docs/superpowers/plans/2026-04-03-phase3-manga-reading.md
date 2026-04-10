# Phase 3: Manga & Reading — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manga home page with browse categories (Top, Trending, Recently Updated, Manhwa, Manhua), manga detail page, full chapter reader with 3 modes (vertical scroll, horizontal swipe, webtoon), chapter navigation, and reading progress tracking.

**Architecture:** Next.js 16 App Router. Types in `web/types/manga.ts` already defined (Phase 1). API client ready at `web/services/api-client.ts`. Reuse `InfiniteScroll`, `Skeleton`, `Button` from Phase 1-2. Dark theme with CSS variables from Phase 1.

**Tech Stack:** Next.js 16, React 19, Tailwind CSS v4, TypeScript

**Backend Endpoints:**
- `/jikan/manga/search`, `/jikan/manga/top`, `/jikan/manga/genres`, `/jikan/manga/:malId`
- `/mangadex/manga/search`, `/mangadex/manga/:id`, `/mangadex/manga/:id/chapters`, `/mangadex/chapter/:id/pages`
- `/mangahook/manga`, `/mangahook/manga/search`, `/mangahook/manga/:id`, `/mangahook/manga/:mangaId/chapter/:chapterId`

**Depends On:** Phase 1 (Foundation & Auth)

---

## File Structure

```
web/
├── app/(main)/manga/
│   ├── page.tsx                              # Manga browse home
│   ├── [id]/
│   │   ├── page.tsx                          # Manga detail
│   │   └── chapter/
│   │       └── [chapterId]/page.tsx          # Chapter reader
├── components/manga/
│   ├── MangaCard.tsx                         # Card for browse grids
│   ├── MangaHero.tsx                         # Detail page hero banner
│   ├── ChapterList.tsx                       # Sortable/filterable chapter list
│   ├── MangaReader.tsx                       # Core reader with 3 modes
│   └── ReaderControls.tsx                    # Reader toolbar (mode switch, nav, fullscreen)
├── services/
│   └── manga.service.ts                      # Manga API calls
├── hooks/
│   └── useManga.ts                           # Manga data hooks (optional, created if needed)
└── types/
    └── manga.ts                              # Already exists from Phase 1
```

---

### Task 1: Create Manga Service

**Files:**
- Create: `web/services/manga.service.ts`

- [ ] **Step 1: Create `web/services/manga.service.ts`**

```typescript
import { apiClient } from "./api-client";
import type { Manga, Chapter } from "@/types/manga";
import type { PaginatedResult } from "@/types/api";

export interface MangaSearchParams {
  q?: string;
  page?: number;
  limit?: number;
  genres?: string;
  status?: string;
  order?: string;
}

export interface MangaHookListParams {
  page?: number;
  type?: string;
  category?: string;
}

export interface ChapterPagesResponse {
  images: string[];
}

export const mangaService = {
  // --- Jikan (MAL metadata) ---

  async searchJikan(
    query: string,
    page = 1,
  ): Promise<PaginatedResult<Manga>> {
    return apiClient.get<PaginatedResult<Manga>>("/jikan/manga/search", {
      q: query,
      page,
    });
  },

  async getTopManga(page = 1): Promise<PaginatedResult<Manga>> {
    return apiClient.get<PaginatedResult<Manga>>("/jikan/manga/top", { page });
  },

  async getJikanMangaById(malId: number): Promise<Manga> {
    return apiClient.get<Manga>(`/jikan/manga/${malId}`);
  },

  async getMangaGenres(): Promise<string[]> {
    return apiClient.get<string[]>("/jikan/manga/genres");
  },

  // --- MangaDex (reading source) ---

  async searchMangadex(
    query: string,
    page = 1,
    limit = 20,
  ): Promise<PaginatedResult<Manga>> {
    return apiClient.get<PaginatedResult<Manga>>("/mangadex/manga/search", {
      q: query,
      page,
      limit,
    });
  },

  async getMangaDetails(id: string): Promise<Manga> {
    return apiClient.get<Manga>(`/mangadex/manga/${id}`);
  },

  async getChapters(mangaId: string): Promise<Chapter[]> {
    return apiClient.get<Chapter[]>(`/mangadex/manga/${mangaId}/chapters`);
  },

  async getChapterPages(chapterId: string): Promise<string[]> {
    const res = await apiClient.get<ChapterPagesResponse>(
      `/mangadex/chapter/${chapterId}/pages`,
    );
    return res.images;
  },

  // --- MangaHook (alternate source) ---

  async getMangaHookList(
    params?: MangaHookListParams,
  ): Promise<PaginatedResult<Manga>> {
    return apiClient.get<PaginatedResult<Manga>>("/mangahook/manga", {
      page: params?.page,
      type: params?.type,
      category: params?.category,
    });
  },

  async searchMangaHook(query: string): Promise<PaginatedResult<Manga>> {
    return apiClient.get<PaginatedResult<Manga>>("/mangahook/manga/search", {
      q: query,
    });
  },

  async getMangaHookDetail(id: string): Promise<Manga> {
    return apiClient.get<Manga>(`/mangahook/manga/${id}`);
  },

  async getMangaHookChapter(
    mangaId: string,
    chapterId: string,
  ): Promise<string[]> {
    const res = await apiClient.get<ChapterPagesResponse>(
      `/mangahook/manga/${mangaId}/chapter/${chapterId}`,
    );
    return res.images;
  },
};
```

- [ ] **Step 2: Commit**

```bash
git add web/services/manga.service.ts
git commit -m "feat(web): add manga service with Jikan, MangaDex, and MangaHook endpoints"
```

---

### Task 2: Create MangaCard Component

**Files:**
- Create: `web/components/manga/MangaCard.tsx`

- [ ] **Step 1: Create `web/components/manga/MangaCard.tsx`**

```tsx
import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/utils";
import type { Manga } from "@/types/manga";

interface MangaCardProps {
  manga: Manga;
  className?: string;
}

export function MangaCard({ manga, className }: MangaCardProps) {
  const statusColors: Record<string, string> = {
    ongoing: "bg-[var(--color-primary)]",
    completed: "bg-[var(--color-success)]",
    hiatus: "bg-yellow-500",
    cancelled: "bg-[var(--color-danger)]",
  };

  return (
    <Link
      href={`/manga/${manga.mangadexId || manga.id}`}
      className={cn(
        "group relative flex flex-col overflow-hidden rounded-xl bg-[var(--color-surface)] border border-[var(--color-border)] transition-all duration-300 hover:border-[var(--color-primary)] hover:shadow-lg hover:shadow-[var(--color-primary)]/5 hover:-translate-y-1",
        className,
      )}
    >
      {/* Cover Image */}
      <div className="relative aspect-[3/4] w-full overflow-hidden">
        {manga.coverImage ? (
          <Image
            src={manga.coverImage}
            alt={manga.title}
            fill
            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 20vw"
            className="object-cover transition-transform duration-300 group-hover:scale-105"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-[var(--color-surface-hover)]">
            <svg
              className="h-12 w-12 text-[var(--color-text-muted)]"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={1.5}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25"
              />
            </svg>
          </div>
        )}

        {/* Gradient overlay */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent" />

        {/* Status badge */}
        {manga.status && (
          <span
            className={cn(
              "absolute top-2 left-2 rounded-md px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-white",
              statusColors[manga.status] || "bg-[var(--color-border)]",
            )}
          >
            {manga.status}
          </span>
        )}

        {/* Rating badge */}
        {manga.rating > 0 && (
          <div className="absolute top-2 right-2 flex items-center gap-1 rounded-md bg-black/60 px-1.5 py-0.5 text-xs font-semibold text-yellow-400 backdrop-blur-sm">
            <svg className="h-3 w-3 fill-current" viewBox="0 0 20 20">
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
            </svg>
            {manga.rating.toFixed(1)}
          </div>
        )}

        {/* Bottom info overlay */}
        <div className="absolute bottom-0 left-0 right-0 p-3">
          {manga.genres && manga.genres.length > 0 && (
            <div className="mb-1 flex flex-wrap gap-1">
              {manga.genres.slice(0, 2).map((genre) => (
                <span
                  key={genre}
                  className="rounded bg-white/10 px-1.5 py-0.5 text-[10px] text-white/80 backdrop-blur-sm"
                >
                  {genre}
                </span>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Title */}
      <div className="flex flex-1 flex-col gap-1 p-3">
        <h3 className="line-clamp-2 text-sm font-semibold leading-tight text-[var(--color-text)] group-hover:text-[var(--color-primary)] transition-colors">
          {manga.title}
        </h3>
        {manga.authors && manga.authors.length > 0 && (
          <p className="line-clamp-1 text-xs text-[var(--color-text-muted)]">
            {manga.authors.join(", ")}
          </p>
        )}
      </div>
    </Link>
  );
}

// Skeleton variant for loading states
export function MangaCardSkeleton() {
  return (
    <div className="flex flex-col overflow-hidden rounded-xl bg-[var(--color-surface)] border border-[var(--color-border)]">
      <div className="aspect-[3/4] w-full animate-pulse bg-[var(--color-surface-hover)]" />
      <div className="flex flex-col gap-2 p-3">
        <div className="h-4 w-3/4 animate-pulse rounded bg-[var(--color-surface-hover)]" />
        <div className="h-3 w-1/2 animate-pulse rounded bg-[var(--color-surface-hover)]" />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/manga/MangaCard.tsx
git commit -m "feat(web): add MangaCard component with cover, status badge, rating"
```

---

### Task 3: Create Manga Browse Page

**Files:**
- Create: `web/app/(main)/manga/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/manga/page.tsx`**

```tsx
"use client";

import { useState, useEffect, useCallback } from "react";
import { mangaService } from "@/services/manga.service";
import { MangaCard, MangaCardSkeleton } from "@/components/manga/MangaCard";
import { Button } from "@/components/ui/Button";
import type { Manga } from "@/types/manga";

type MangaCategory = "top" | "trending" | "updated" | "manhwa" | "manhua";

interface CategoryConfig {
  key: MangaCategory;
  label: string;
  fetchFn: (page: number) => Promise<{ data: Manga[]; totalPages: number }>;
}

const categories: CategoryConfig[] = [
  {
    key: "top",
    label: "Top Manga",
    fetchFn: (page) => mangaService.getTopManga(page),
  },
  {
    key: "trending",
    label: "Trending",
    fetchFn: (page) =>
      mangaService.getMangaHookList({ page, category: "trending" }),
  },
  {
    key: "updated",
    label: "Recently Updated",
    fetchFn: (page) =>
      mangaService.getMangaHookList({ page, category: "updated" }),
  },
  {
    key: "manhwa",
    label: "Manhwa",
    fetchFn: (page) =>
      mangaService.getMangaHookList({ page, type: "manhwa" }),
  },
  {
    key: "manhua",
    label: "Manhua",
    fetchFn: (page) =>
      mangaService.getMangaHookList({ page, type: "manhua" }),
  },
];

export default function MangaBrowsePage() {
  const [activeCategory, setActiveCategory] = useState<MangaCategory>("top");
  const [mangaList, setMangaList] = useState<Manga[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<Manga[] | null>(null);
  const [searchLoading, setSearchLoading] = useState(false);

  const fetchCategory = useCallback(
    async (category: MangaCategory, pageNum: number) => {
      setLoading(true);
      try {
        const config = categories.find((c) => c.key === category)!;
        const result = await config.fetchFn(pageNum);
        if (pageNum === 1) {
          setMangaList(result.data);
        } else {
          setMangaList((prev) => [...prev, ...result.data]);
        }
        setTotalPages(result.totalPages);
      } catch (err) {
        console.error("Failed to fetch manga:", err);
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  useEffect(() => {
    setMangaList([]);
    setPage(1);
    setSearchResults(null);
    setSearchQuery("");
    fetchCategory(activeCategory, 1);
  }, [activeCategory, fetchCategory]);

  const loadMore = () => {
    if (page < totalPages && !loading) {
      const nextPage = page + 1;
      setPage(nextPage);
      fetchCategory(activeCategory, nextPage);
    }
  };

  // Debounced search
  useEffect(() => {
    if (!searchQuery.trim()) {
      setSearchResults(null);
      return;
    }

    const timer = setTimeout(async () => {
      setSearchLoading(true);
      try {
        const result = await mangaService.searchMangadex(searchQuery);
        setSearchResults(result.data);
      } catch (err) {
        console.error("Search failed:", err);
      } finally {
        setSearchLoading(false);
      }
    }, 500);

    return () => clearTimeout(timer);
  }, [searchQuery]);

  const displayedManga = searchResults ?? mangaList;
  const isSearching = searchQuery.trim().length > 0;

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-[var(--color-text)]">Manga</h1>
        <p className="mt-1 text-sm text-[var(--color-text-muted)]">
          Browse and discover manga, manhwa, and manhua
        </p>
      </div>

      {/* Search Bar */}
      <div className="relative mb-6">
        <svg
          className="absolute left-3 top-1/2 h-5 w-5 -translate-y-1/2 text-[var(--color-text-muted)]"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          />
        </svg>
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search manga by title..."
          className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] py-3 pl-10 pr-4 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:border-[var(--color-primary)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]/20"
        />
        {searchQuery && (
          <button
            onClick={() => setSearchQuery("")}
            className="absolute right-3 top-1/2 -translate-y-1/2 rounded-full p-1 text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text)]"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        )}
      </div>

      {/* Category Tabs */}
      {!isSearching && (
        <div className="mb-6 flex gap-2 overflow-x-auto pb-2 scrollbar-none">
          {categories.map((cat) => (
            <button
              key={cat.key}
              onClick={() => setActiveCategory(cat.key)}
              className={`whitespace-nowrap rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
                activeCategory === cat.key
                  ? "bg-[var(--color-primary)] text-white"
                  : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text)] border border-[var(--color-border)]"
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>
      )}

      {/* Search Results Label */}
      {isSearching && (
        <div className="mb-4 flex items-center gap-2">
          <span className="text-sm text-[var(--color-text-muted)]">
            {searchLoading
              ? "Searching..."
              : `${searchResults?.length ?? 0} results for "${searchQuery}"`}
          </span>
        </div>
      )}

      {/* Manga Grid */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
        {(loading && displayedManga.length === 0) || searchLoading
          ? Array.from({ length: 12 }).map((_, i) => (
              <MangaCardSkeleton key={i} />
            ))
          : displayedManga.map((manga) => (
              <MangaCard key={manga.id} manga={manga} />
            ))}
      </div>

      {/* Empty State */}
      {!loading && !searchLoading && displayedManga.length === 0 && (
        <div className="flex flex-col items-center justify-center py-20">
          <svg
            className="mb-4 h-16 w-16 text-[var(--color-text-muted)]"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25"
            />
          </svg>
          <p className="text-[var(--color-text-muted)]">No manga found</p>
        </div>
      )}

      {/* Load More */}
      {!isSearching && page < totalPages && displayedManga.length > 0 && (
        <div className="mt-8 flex justify-center">
          <Button
            variant="secondary"
            onClick={loadMore}
            loading={loading}
          >
            Load More
          </Button>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/manga/page.tsx
git commit -m "feat(web): add manga browse page with category tabs and search"
```

---

### Task 4: Create MangaHero Component

**Files:**
- Create: `web/components/manga/MangaHero.tsx`

- [ ] **Step 1: Create `web/components/manga/MangaHero.tsx`**

```tsx
import Image from "next/image";
import { cn } from "@/lib/utils";
import { formatDate } from "@/lib/utils";
import type { Manga } from "@/types/manga";

interface MangaHeroProps {
  manga: Manga;
  onReadFirst?: () => void;
  onAddToList?: () => void;
  isInList?: boolean;
  className?: string;
}

export function MangaHero({
  manga,
  onReadFirst,
  onAddToList,
  isInList = false,
  className,
}: MangaHeroProps) {
  const statusColors: Record<string, string> = {
    ongoing: "text-[var(--color-primary)]",
    completed: "text-[var(--color-success)]",
    hiatus: "text-yellow-400",
    cancelled: "text-[var(--color-danger)]",
  };

  return (
    <div className={cn("relative overflow-hidden", className)}>
      {/* Background blur */}
      <div className="absolute inset-0">
        {manga.coverImage && (
          <Image
            src={manga.coverImage}
            alt=""
            fill
            className="object-cover blur-2xl opacity-20 scale-110"
            priority
          />
        )}
        <div className="absolute inset-0 bg-gradient-to-b from-[var(--color-bg)]/60 via-[var(--color-bg)]/80 to-[var(--color-bg)]" />
      </div>

      {/* Content */}
      <div className="relative mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-6 sm:flex-row sm:gap-8">
          {/* Cover */}
          <div className="flex-shrink-0 self-center sm:self-start">
            <div className="relative h-[300px] w-[200px] overflow-hidden rounded-xl border-2 border-[var(--color-border)] shadow-2xl sm:h-[360px] sm:w-[240px]">
              {manga.coverImage ? (
                <Image
                  src={manga.coverImage}
                  alt={manga.title}
                  fill
                  sizes="240px"
                  className="object-cover"
                  priority
                />
              ) : (
                <div className="flex h-full w-full items-center justify-center bg-[var(--color-surface)]">
                  <svg
                    className="h-16 w-16 text-[var(--color-text-muted)]"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={1.5}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25"
                    />
                  </svg>
                </div>
              )}
            </div>
          </div>

          {/* Info */}
          <div className="flex flex-1 flex-col justify-center gap-4">
            <div>
              <h1 className="text-2xl font-bold leading-tight text-[var(--color-text)] sm:text-3xl lg:text-4xl">
                {manga.title}
              </h1>
              {manga.altTitles && Object.values(manga.altTitles).length > 0 && (
                <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                  {Object.values(manga.altTitles)[0]}
                </p>
              )}
            </div>

            {/* Meta row */}
            <div className="flex flex-wrap items-center gap-3 text-sm">
              {manga.status && (
                <span
                  className={cn(
                    "font-semibold uppercase",
                    statusColors[manga.status] || "text-[var(--color-text-muted)]",
                  )}
                >
                  {manga.status}
                </span>
              )}
              {manga.year && (
                <span className="text-[var(--color-text-muted)]">
                  {manga.year}
                </span>
              )}
              {manga.rating > 0 && (
                <span className="flex items-center gap-1 text-yellow-400">
                  <svg className="h-4 w-4 fill-current" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                  </svg>
                  {manga.rating.toFixed(1)}
                </span>
              )}
            </div>

            {/* Authors / Artists */}
            <div className="flex flex-wrap gap-4 text-sm">
              {manga.authors && manga.authors.length > 0 && (
                <div>
                  <span className="text-[var(--color-text-muted)]">Author: </span>
                  <span className="text-[var(--color-text)]">
                    {manga.authors.join(", ")}
                  </span>
                </div>
              )}
              {manga.artists && manga.artists.length > 0 && (
                <div>
                  <span className="text-[var(--color-text-muted)]">Artist: </span>
                  <span className="text-[var(--color-text)]">
                    {manga.artists.join(", ")}
                  </span>
                </div>
              )}
            </div>

            {/* Genres */}
            {manga.genres && manga.genres.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {manga.genres.map((genre) => (
                  <span
                    key={genre}
                    className="rounded-lg bg-[var(--color-surface)] px-3 py-1 text-xs font-medium text-[var(--color-text-muted)] border border-[var(--color-border)]"
                  >
                    {genre}
                  </span>
                ))}
              </div>
            )}

            {/* Description */}
            {manga.description && (
              <p className="line-clamp-4 text-sm leading-relaxed text-[var(--color-text-muted)]">
                {manga.description}
              </p>
            )}

            {/* Actions */}
            <div className="flex flex-wrap gap-3 pt-2">
              <button
                onClick={onReadFirst}
                className="inline-flex items-center gap-2 rounded-xl bg-[var(--color-primary)] px-6 py-3 text-sm font-semibold text-white transition-colors hover:bg-[var(--color-primary-hover)]"
              >
                <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25"
                  />
                </svg>
                Start Reading
              </button>
              <button
                onClick={onAddToList}
                className={cn(
                  "inline-flex items-center gap-2 rounded-xl border px-6 py-3 text-sm font-semibold transition-colors",
                  isInList
                    ? "border-[var(--color-primary)] bg-[var(--color-primary)]/10 text-[var(--color-primary)]"
                    : "border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text)] hover:bg-[var(--color-surface-hover)]",
                )}
              >
                <svg
                  className="h-5 w-5"
                  fill={isInList ? "currentColor" : "none"}
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={2}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z"
                  />
                </svg>
                {isInList ? "In Reading List" : "Add to List"}
              </button>
            </div>

            {/* Timestamps */}
            <div className="flex gap-4 text-xs text-[var(--color-text-muted)]">
              {manga.createdAt && (
                <span>Added {formatDate(manga.createdAt)}</span>
              )}
              {manga.updatedAt && (
                <span>Updated {formatDate(manga.updatedAt)}</span>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/manga/MangaHero.tsx
git commit -m "feat(web): add MangaHero detail page banner component"
```

---

### Task 5: Create ChapterList Component

**Files:**
- Create: `web/components/manga/ChapterList.tsx`

- [ ] **Step 1: Create `web/components/manga/ChapterList.tsx`**

```tsx
"use client";

import { useState, useMemo } from "react";
import Link from "next/link";
import { cn, formatDate } from "@/lib/utils";
import type { Chapter } from "@/types/manga";

type SortField = "number" | "publishedAt";
type SortOrder = "asc" | "desc";

interface ChapterListProps {
  chapters: Chapter[];
  mangaId: string;
  className?: string;
}

export function ChapterList({ chapters, mangaId, className }: ChapterListProps) {
  const [sortField, setSortField] = useState<SortField>("number");
  const [sortOrder, setSortOrder] = useState<SortOrder>("desc");
  const [filterQuery, setFilterQuery] = useState("");
  const [languageFilter, setLanguageFilter] = useState<string>("all");

  // Extract available languages
  const languages = useMemo(() => {
    const langSet = new Set(chapters.map((ch) => ch.language));
    return Array.from(langSet).sort();
  }, [chapters]);

  // Sort and filter chapters
  const filteredChapters = useMemo(() => {
    let result = [...chapters];

    // Language filter
    if (languageFilter !== "all") {
      result = result.filter((ch) => ch.language === languageFilter);
    }

    // Text filter
    if (filterQuery.trim()) {
      const q = filterQuery.toLowerCase();
      result = result.filter(
        (ch) =>
          ch.number.toString().includes(q) ||
          ch.title?.toLowerCase().includes(q) ||
          ch.scanlationGroup?.toLowerCase().includes(q),
      );
    }

    // Sort
    result.sort((a, b) => {
      let cmp: number;
      if (sortField === "number") {
        cmp = a.number - b.number;
      } else {
        cmp =
          new Date(a.publishedAt).getTime() -
          new Date(b.publishedAt).getTime();
      }
      return sortOrder === "asc" ? cmp : -cmp;
    });

    return result;
  }, [chapters, sortField, sortOrder, filterQuery, languageFilter]);

  const toggleSort = (field: SortField) => {
    if (sortField === field) {
      setSortOrder((prev) => (prev === "asc" ? "desc" : "asc"));
    } else {
      setSortField(field);
      setSortOrder("desc");
    }
  };

  const SortIcon = ({ field }: { field: SortField }) => (
    <svg
      className={cn(
        "h-3.5 w-3.5 transition-transform",
        sortField === field ? "text-[var(--color-primary)]" : "text-[var(--color-text-muted)]",
        sortField === field && sortOrder === "asc" && "rotate-180",
      )}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2}
    >
      <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
    </svg>
  );

  return (
    <div className={cn("flex flex-col gap-4", className)}>
      {/* Header & Controls */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <h2 className="text-lg font-bold text-[var(--color-text)]">
          Chapters{" "}
          <span className="text-sm font-normal text-[var(--color-text-muted)]">
            ({filteredChapters.length})
          </span>
        </h2>

        <div className="flex flex-wrap items-center gap-2">
          {/* Language filter */}
          {languages.length > 1 && (
            <select
              value={languageFilter}
              onChange={(e) => setLanguageFilter(e.target.value)}
              className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-1.5 text-xs text-[var(--color-text)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]/20"
            >
              <option value="all">All Languages</option>
              {languages.map((lang) => (
                <option key={lang} value={lang}>
                  {lang.toUpperCase()}
                </option>
              ))}
            </select>
          )}

          {/* Sort buttons */}
          <button
            onClick={() => toggleSort("number")}
            className="inline-flex items-center gap-1 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-1.5 text-xs text-[var(--color-text)] hover:bg-[var(--color-surface-hover)]"
          >
            # Number <SortIcon field="number" />
          </button>
          <button
            onClick={() => toggleSort("publishedAt")}
            className="inline-flex items-center gap-1 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-1.5 text-xs text-[var(--color-text)] hover:bg-[var(--color-surface-hover)]"
          >
            Date <SortIcon field="publishedAt" />
          </button>
        </div>
      </div>

      {/* Search */}
      <div className="relative">
        <svg
          className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-text-muted)]"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          />
        </svg>
        <input
          type="text"
          value={filterQuery}
          onChange={(e) => setFilterQuery(e.target.value)}
          placeholder="Search chapters by number, title, or group..."
          className="w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] py-2 pl-9 pr-4 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:border-[var(--color-primary)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]/20"
        />
      </div>

      {/* Chapter List */}
      <div className="flex flex-col divide-y divide-[var(--color-border)] rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden">
        {filteredChapters.length === 0 ? (
          <div className="px-4 py-8 text-center text-sm text-[var(--color-text-muted)]">
            No chapters found
          </div>
        ) : (
          filteredChapters.map((chapter) => (
            <Link
              key={chapter.id}
              href={`/manga/${mangaId}/chapter/${chapter.mangadexChapterId || chapter.id}`}
              className="group flex items-center justify-between gap-4 px-4 py-3 transition-colors hover:bg-[var(--color-surface-hover)]"
            >
              <div className="flex min-w-0 flex-1 items-center gap-3">
                <span className="flex-shrink-0 rounded-md bg-[var(--color-bg)] px-2 py-0.5 text-xs font-mono font-semibold text-[var(--color-primary)]">
                  Ch. {chapter.number}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm text-[var(--color-text)] group-hover:text-[var(--color-primary)] transition-colors">
                    {chapter.title || `Chapter ${chapter.number}`}
                  </p>
                  <div className="flex items-center gap-2 text-xs text-[var(--color-text-muted)]">
                    {chapter.volume && <span>Vol. {chapter.volume}</span>}
                    {chapter.scanlationGroup && (
                      <span>{chapter.scanlationGroup}</span>
                    )}
                    {chapter.pages > 0 && <span>{chapter.pages} pages</span>}
                  </div>
                </div>
              </div>

              <div className="flex flex-shrink-0 items-center gap-3">
                <span className="rounded bg-[var(--color-bg)] px-1.5 py-0.5 text-[10px] font-medium uppercase text-[var(--color-text-muted)]">
                  {chapter.language}
                </span>
                <span className="text-xs text-[var(--color-text-muted)]">
                  {formatDate(chapter.publishedAt)}
                </span>
                <svg
                  className="h-4 w-4 text-[var(--color-text-muted)] opacity-0 transition-opacity group-hover:opacity-100"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={2}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </Link>
          ))
        )}
      </div>
    </div>
  );
}

// Skeleton for loading
export function ChapterListSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <div className="h-6 w-32 animate-pulse rounded bg-[var(--color-surface-hover)]" />
      <div className="flex flex-col divide-y divide-[var(--color-border)] rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden">
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="flex items-center gap-3 px-4 py-3">
            <div className="h-5 w-14 animate-pulse rounded bg-[var(--color-surface-hover)]" />
            <div className="flex-1 space-y-1.5">
              <div className="h-4 w-3/4 animate-pulse rounded bg-[var(--color-surface-hover)]" />
              <div className="h-3 w-1/3 animate-pulse rounded bg-[var(--color-surface-hover)]" />
            </div>
            <div className="h-3 w-16 animate-pulse rounded bg-[var(--color-surface-hover)]" />
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/manga/ChapterList.tsx
git commit -m "feat(web): add ChapterList with sort, filter, and language selection"
```

---

### Task 6: Create Manga Detail Page

**Files:**
- Create: `web/app/(main)/manga/[id]/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/manga/[id]/page.tsx`**

```tsx
"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { mangaService } from "@/services/manga.service";
import { MangaHero } from "@/components/manga/MangaHero";
import { ChapterList, ChapterListSkeleton } from "@/components/manga/ChapterList";
import { Skeleton } from "@/components/ui/Skeleton";
import type { Manga, Chapter } from "@/types/manga";

export default function MangaDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const [manga, setManga] = useState<Manga | null>(null);
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [loading, setLoading] = useState(true);
  const [chaptersLoading, setChaptersLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!params.id) return;

    const fetchManga = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await mangaService.getMangaDetails(params.id);
        setManga(data);
      } catch (err) {
        console.error("Failed to load manga:", err);
        setError("Failed to load manga details. Please try again.");
      } finally {
        setLoading(false);
      }
    };

    const fetchChapters = async () => {
      setChaptersLoading(true);
      try {
        const data = await mangaService.getChapters(params.id);
        setChapters(data);
      } catch (err) {
        console.error("Failed to load chapters:", err);
      } finally {
        setChaptersLoading(false);
      }
    };

    fetchManga();
    fetchChapters();
  }, [params.id]);

  const handleReadFirst = () => {
    if (chapters.length === 0) return;
    // Sort ascending and pick first chapter
    const sorted = [...chapters].sort((a, b) => a.number - b.number);
    const first = sorted[0];
    router.push(
      `/manga/${params.id}/chapter/${first.mangadexChapterId || first.id}`,
    );
  };

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20">
        <p className="mb-4 text-[var(--color-danger)]">{error}</p>
        <button
          onClick={() => window.location.reload()}
          className="rounded-lg bg-[var(--color-primary)] px-4 py-2 text-sm text-white hover:bg-[var(--color-primary-hover)]"
        >
          Retry
        </button>
      </div>
    );
  }

  return (
    <div className="min-h-screen">
      {/* Hero */}
      {loading ? (
        <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          <div className="flex flex-col gap-6 sm:flex-row sm:gap-8">
            <Skeleton className="h-[300px] w-[200px] flex-shrink-0 rounded-xl sm:h-[360px] sm:w-[240px]" />
            <div className="flex flex-1 flex-col gap-4">
              <Skeleton className="h-10 w-3/4" />
              <Skeleton className="h-5 w-1/2" />
              <Skeleton className="h-4 w-1/3" />
              <div className="flex gap-2">
                <Skeleton className="h-8 w-20 rounded-lg" />
                <Skeleton className="h-8 w-20 rounded-lg" />
                <Skeleton className="h-8 w-20 rounded-lg" />
              </div>
              <Skeleton className="h-20 w-full" />
              <div className="flex gap-3">
                <Skeleton className="h-12 w-36 rounded-xl" />
                <Skeleton className="h-12 w-36 rounded-xl" />
              </div>
            </div>
          </div>
        </div>
      ) : manga ? (
        <MangaHero
          manga={manga}
          onReadFirst={handleReadFirst}
        />
      ) : null}

      {/* Chapter List */}
      <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        {chaptersLoading ? (
          <ChapterListSkeleton />
        ) : (
          <ChapterList
            chapters={chapters}
            mangaId={params.id}
          />
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/manga/\[id\]/page.tsx
git commit -m "feat(web): add manga detail page with hero banner and chapter list"
```

---

### Task 7: Create MangaReader Component

**Files:**
- Create: `web/components/manga/MangaReader.tsx`

- [ ] **Step 1: Create `web/components/manga/MangaReader.tsx`**

```tsx
"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import Image from "next/image";
import { cn } from "@/lib/utils";

export type ReadingMode = "vertical-scroll" | "horizontal-swipe" | "webtoon";

interface MangaReaderProps {
  pages: string[];
  mode: ReadingMode;
  onPageChange?: (page: number) => void;
  onChapterEnd?: () => void;
  onChapterPrev?: () => void;
  className?: string;
}

export function MangaReader({
  pages,
  mode,
  onPageChange,
  onChapterEnd,
  onChapterPrev,
  className,
}: MangaReaderProps) {
  const [currentPage, setCurrentPage] = useState(0);
  const [loadedImages, setLoadedImages] = useState<Set<number>>(new Set());
  const containerRef = useRef<HTMLDivElement>(null);
  const touchStartX = useRef<number | null>(null);
  const touchStartY = useRef<number | null>(null);

  // Reset page when pages change
  useEffect(() => {
    setCurrentPage(0);
    setLoadedImages(new Set());
  }, [pages]);

  // Notify parent of page changes
  useEffect(() => {
    onPageChange?.(currentPage);
  }, [currentPage, onPageChange]);

  const goToPage = useCallback(
    (page: number) => {
      if (page < 0) {
        onChapterPrev?.();
        return;
      }
      if (page >= pages.length) {
        onChapterEnd?.();
        return;
      }
      setCurrentPage(page);
    },
    [pages.length, onChapterEnd, onChapterPrev],
  );

  const nextPage = useCallback(() => goToPage(currentPage + 1), [currentPage, goToPage]);
  const prevPage = useCallback(() => goToPage(currentPage - 1), [currentPage, goToPage]);

  // Keyboard navigation (horizontal mode)
  useEffect(() => {
    if (mode !== "horizontal-swipe") return;

    const handleKeyDown = (e: KeyboardEvent) => {
      switch (e.key) {
        case "ArrowRight":
          e.preventDefault();
          nextPage();
          break;
        case "ArrowLeft":
          e.preventDefault();
          prevPage();
          break;
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [mode, nextPage, prevPage]);

  // Touch swipe handling (horizontal mode)
  const handleTouchStart = (e: React.TouchEvent) => {
    if (mode !== "horizontal-swipe") return;
    touchStartX.current = e.touches[0].clientX;
    touchStartY.current = e.touches[0].clientY;
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    if (mode !== "horizontal-swipe" || touchStartX.current === null || touchStartY.current === null) return;

    const deltaX = e.changedTouches[0].clientX - touchStartX.current;
    const deltaY = e.changedTouches[0].clientY - touchStartY.current;

    // Only register horizontal swipes (ignore vertical scrolls)
    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
      if (deltaX < 0) {
        nextPage();
      } else {
        prevPage();
      }
    }

    touchStartX.current = null;
    touchStartY.current = null;
  };

  // Click navigation for horizontal mode (left/right halves)
  const handleHorizontalClick = (e: React.MouseEvent) => {
    if (mode !== "horizontal-swipe") return;
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    if (clickX < rect.width / 2) {
      prevPage();
    } else {
      nextPage();
    }
  };

  // Scroll-based page tracking for vertical / webtoon modes
  useEffect(() => {
    if (mode === "horizontal-swipe") return;

    const container = containerRef.current;
    if (!container) return;

    const handleScroll = () => {
      const children = container.children;
      const scrollTop = container.scrollTop;
      const containerHeight = container.clientHeight;
      let closestIdx = 0;
      let closestDist = Infinity;

      for (let i = 0; i < children.length; i++) {
        const child = children[i] as HTMLElement;
        const childCenter = child.offsetTop + child.offsetHeight / 2;
        const viewCenter = scrollTop + containerHeight / 2;
        const dist = Math.abs(childCenter - viewCenter);
        if (dist < closestDist) {
          closestDist = dist;
          closestIdx = i;
        }
      }

      if (closestIdx !== currentPage) {
        setCurrentPage(closestIdx);
      }

      // Detect reaching the bottom
      const atBottom =
        container.scrollHeight - container.scrollTop - container.clientHeight < 100;
      if (atBottom && closestIdx === pages.length - 1) {
        onChapterEnd?.();
      }
    };

    container.addEventListener("scroll", handleScroll, { passive: true });
    return () => container.removeEventListener("scroll", handleScroll);
  }, [mode, currentPage, pages.length, onChapterEnd]);

  const onImageLoad = (index: number) => {
    setLoadedImages((prev) => new Set(prev).add(index));
  };

  // ---- VERTICAL SCROLL MODE ----
  if (mode === "vertical-scroll") {
    return (
      <div
        ref={containerRef}
        className={cn(
          "flex flex-col items-center gap-1 overflow-y-auto",
          className,
        )}
      >
        {pages.map((src, i) => (
          <div key={i} className="relative w-full max-w-3xl">
            {!loadedImages.has(i) && (
              <div className="flex h-[600px] w-full items-center justify-center bg-[var(--color-surface)]">
                <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--color-primary)] border-t-transparent" />
              </div>
            )}
            <Image
              src={src}
              alt={`Page ${i + 1}`}
              width={800}
              height={1200}
              className={cn(
                "w-full h-auto select-none",
                !loadedImages.has(i) && "hidden",
              )}
              onLoad={() => onImageLoad(i)}
              priority={i < 3}
              unoptimized
            />
          </div>
        ))}
      </div>
    );
  }

  // ---- HORIZONTAL SWIPE MODE ----
  if (mode === "horizontal-swipe") {
    return (
      <div
        ref={containerRef}
        className={cn(
          "relative flex h-full items-center justify-center overflow-hidden select-none",
          className,
        )}
        onClick={handleHorizontalClick}
        onTouchStart={handleTouchStart}
        onTouchEnd={handleTouchEnd}
      >
        {/* Current page */}
        <div className="relative flex h-full w-full items-center justify-center">
          {!loadedImages.has(currentPage) && (
            <div className="absolute flex h-full w-full items-center justify-center bg-[var(--color-surface)]">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--color-primary)] border-t-transparent" />
            </div>
          )}
          <Image
            src={pages[currentPage]}
            alt={`Page ${currentPage + 1}`}
            width={800}
            height={1200}
            className="max-h-full max-w-full object-contain"
            onLoad={() => onImageLoad(currentPage)}
            priority
            unoptimized
          />
        </div>

        {/* Left arrow hint */}
        {currentPage > 0 && (
          <div className="absolute left-0 top-0 bottom-0 flex w-16 items-center justify-start pl-2 opacity-0 hover:opacity-100 transition-opacity">
            <div className="rounded-full bg-black/50 p-2 backdrop-blur-sm">
              <svg className="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
              </svg>
            </div>
          </div>
        )}

        {/* Right arrow hint */}
        {currentPage < pages.length - 1 && (
          <div className="absolute right-0 top-0 bottom-0 flex w-16 items-center justify-end pr-2 opacity-0 hover:opacity-100 transition-opacity">
            <div className="rounded-full bg-black/50 p-2 backdrop-blur-sm">
              <svg className="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
              </svg>
            </div>
          </div>
        )}

        {/* Preload adjacent pages */}
        {currentPage + 1 < pages.length && (
          <Image
            src={pages[currentPage + 1]}
            alt=""
            width={1}
            height={1}
            className="hidden"
            onLoad={() => onImageLoad(currentPage + 1)}
            unoptimized
          />
        )}
        {currentPage - 1 >= 0 && (
          <Image
            src={pages[currentPage - 1]}
            alt=""
            width={1}
            height={1}
            className="hidden"
            onLoad={() => onImageLoad(currentPage - 1)}
            unoptimized
          />
        )}
      </div>
    );
  }

  // ---- WEBTOON MODE ----
  return (
    <div
      ref={containerRef}
      className={cn(
        "flex flex-col items-center overflow-y-auto",
        className,
      )}
    >
      {pages.map((src, i) => (
        <div key={i} className="relative w-full max-w-2xl">
          {!loadedImages.has(i) && (
            <div className="flex h-[800px] w-full items-center justify-center bg-[var(--color-surface)]">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--color-primary)] border-t-transparent" />
            </div>
          )}
          <Image
            src={src}
            alt={`Page ${i + 1}`}
            width={720}
            height={1280}
            className={cn(
              "w-full h-auto select-none",
              !loadedImages.has(i) && "hidden",
            )}
            onLoad={() => onImageLoad(i)}
            priority={i < 3}
            unoptimized
          />
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/manga/MangaReader.tsx
git commit -m "feat(web): add MangaReader with vertical-scroll, horizontal-swipe, and webtoon modes"
```

---

### Task 8: Create ReaderControls Component

**Files:**
- Create: `web/components/manga/ReaderControls.tsx`

- [ ] **Step 1: Create `web/components/manga/ReaderControls.tsx`**

```tsx
"use client";

import { useState, useEffect, useCallback } from "react";
import { cn } from "@/lib/utils";
import type { ReadingMode } from "./MangaReader";

interface ReaderControlsProps {
  currentPage: number;
  totalPages: number;
  mode: ReadingMode;
  onModeChange: (mode: ReadingMode) => void;
  onPrevChapter?: () => void;
  onNextChapter?: () => void;
  hasPrevChapter: boolean;
  hasNextChapter: boolean;
  chapterTitle?: string;
  className?: string;
}

const modeConfig: { key: ReadingMode; label: string; icon: JSX.Element }[] = [
  {
    key: "vertical-scroll",
    label: "Vertical",
    icon: (
      <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
      </svg>
    ),
  },
  {
    key: "horizontal-swipe",
    label: "Horizontal",
    icon: (
      <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M14 5l7 7m0 0l-7 7m7-7H3" />
      </svg>
    ),
  },
  {
    key: "webtoon",
    label: "Webtoon",
    icon: (
      <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
      </svg>
    ),
  },
];

export function ReaderControls({
  currentPage,
  totalPages,
  mode,
  onModeChange,
  onPrevChapter,
  onNextChapter,
  hasPrevChapter,
  hasNextChapter,
  chapterTitle,
  className,
}: ReaderControlsProps) {
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [visible, setVisible] = useState(true);
  const [hideTimer, setHideTimer] = useState<NodeJS.Timeout | null>(null);

  // Auto-hide controls after 3 seconds of inactivity
  const resetHideTimer = useCallback(() => {
    setVisible(true);
    if (hideTimer) clearTimeout(hideTimer);
    const timer = setTimeout(() => setVisible(false), 3000);
    setHideTimer(timer);
  }, [hideTimer]);

  useEffect(() => {
    const handleMouseMove = () => resetHideTimer();
    window.addEventListener("mousemove", handleMouseMove);
    resetHideTimer();
    return () => {
      window.removeEventListener("mousemove", handleMouseMove);
      if (hideTimer) clearTimeout(hideTimer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Fullscreen
  const toggleFullscreen = async () => {
    try {
      if (!document.fullscreenElement) {
        await document.documentElement.requestFullscreen();
        setIsFullscreen(true);
      } else {
        await document.exitFullscreen();
        setIsFullscreen(false);
      }
    } catch {
      // Fullscreen not supported
    }
  };

  useEffect(() => {
    const handleFsChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener("fullscreenchange", handleFsChange);
    return () =>
      document.removeEventListener("fullscreenchange", handleFsChange);
  }, []);

  // Persist reading mode preference
  useEffect(() => {
    if (typeof window !== "undefined") {
      localStorage.setItem("manga_reading_mode", mode);
    }
  }, [mode]);

  return (
    <>
      {/* Top bar */}
      <div
        className={cn(
          "fixed top-0 left-0 right-0 z-50 flex items-center justify-between gap-4 bg-[var(--color-bg)]/90 px-4 py-3 backdrop-blur-md border-b border-[var(--color-border)] transition-transform duration-300",
          visible ? "translate-y-0" : "-translate-y-full",
          className,
        )}
      >
        {/* Left: back + chapter title */}
        <div className="flex items-center gap-3 min-w-0">
          <button
            onClick={() => window.history.back()}
            className="flex-shrink-0 rounded-lg p-2 text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text)]"
          >
            <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          {chapterTitle && (
            <span className="truncate text-sm font-medium text-[var(--color-text)]">
              {chapterTitle}
            </span>
          )}
        </div>

        {/* Right: mode selector + fullscreen */}
        <div className="flex items-center gap-2">
          {/* Mode switcher */}
          <div className="flex rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden">
            {modeConfig.map((m) => (
              <button
                key={m.key}
                onClick={() => onModeChange(m.key)}
                title={m.label}
                className={cn(
                  "flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium transition-colors",
                  mode === m.key
                    ? "bg-[var(--color-primary)] text-white"
                    : "text-[var(--color-text-muted)] hover:text-[var(--color-text)] hover:bg-[var(--color-surface-hover)]",
                )}
              >
                {m.icon}
                <span className="hidden sm:inline">{m.label}</span>
              </button>
            ))}
          </div>

          {/* Fullscreen */}
          <button
            onClick={toggleFullscreen}
            className="rounded-lg p-2 text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text)]"
            title={isFullscreen ? "Exit fullscreen" : "Fullscreen"}
          >
            {isFullscreen ? (
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5l5.25 5.25" />
              </svg>
            ) : (
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
              </svg>
            )}
          </button>
        </div>
      </div>

      {/* Bottom bar */}
      <div
        className={cn(
          "fixed bottom-0 left-0 right-0 z-50 flex items-center justify-between gap-4 bg-[var(--color-bg)]/90 px-4 py-3 backdrop-blur-md border-t border-[var(--color-border)] transition-transform duration-300",
          visible ? "translate-y-0" : "translate-y-full",
        )}
      >
        {/* Prev chapter */}
        <button
          onClick={onPrevChapter}
          disabled={!hasPrevChapter}
          className="inline-flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-medium text-[var(--color-text)] transition-colors hover:bg-[var(--color-surface-hover)] disabled:opacity-30 disabled:pointer-events-none"
        >
          <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
          <span className="hidden sm:inline">Prev Chapter</span>
        </button>

        {/* Page indicator */}
        <div className="flex items-center gap-3">
          <span className="rounded-lg bg-[var(--color-surface)] px-3 py-1.5 text-sm font-mono font-medium text-[var(--color-text)] border border-[var(--color-border)]">
            {currentPage + 1} / {totalPages}
          </span>

          {/* Page progress bar */}
          <div className="hidden w-40 sm:block">
            <div className="h-1.5 w-full rounded-full bg-[var(--color-border)]">
              <div
                className="h-full rounded-full bg-[var(--color-primary)] transition-all duration-200"
                style={{
                  width: `${totalPages > 1 ? ((currentPage) / (totalPages - 1)) * 100 : 100}%`,
                }}
              />
            </div>
          </div>
        </div>

        {/* Next chapter */}
        <button
          onClick={onNextChapter}
          disabled={!hasNextChapter}
          className="inline-flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-medium text-[var(--color-text)] transition-colors hover:bg-[var(--color-surface-hover)] disabled:opacity-30 disabled:pointer-events-none"
        >
          <span className="hidden sm:inline">Next Chapter</span>
          <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>
    </>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/manga/ReaderControls.tsx
git commit -m "feat(web): add ReaderControls with mode switcher, navigation, fullscreen, page indicator"
```

---

### Task 9: Create Chapter Reader Page

**Files:**
- Create: `web/app/(main)/manga/[id]/chapter/[chapterId]/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/manga/[id]/chapter/[chapterId]/page.tsx`**

```tsx
"use client";

import { useState, useEffect, useCallback, useMemo } from "react";
import { useParams, useRouter } from "next/navigation";
import { mangaService } from "@/services/manga.service";
import { MangaReader, type ReadingMode } from "@/components/manga/MangaReader";
import { ReaderControls } from "@/components/manga/ReaderControls";
import type { Chapter } from "@/types/manga";

export default function ChapterReaderPage() {
  const params = useParams<{ id: string; chapterId: string }>();
  const router = useRouter();

  const [pages, setPages] = useState<string[]>([]);
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(0);
  const [mode, setMode] = useState<ReadingMode>(() => {
    if (typeof window !== "undefined") {
      return (localStorage.getItem("manga_reading_mode") as ReadingMode) || "vertical-scroll";
    }
    return "vertical-scroll";
  });

  // Load chapter pages
  useEffect(() => {
    if (!params.chapterId) return;

    const fetchPages = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await mangaService.getChapterPages(params.chapterId);
        setPages(data);
      } catch (err) {
        console.error("Failed to load chapter pages:", err);
        setError("Failed to load chapter. Please try again.");
      } finally {
        setLoading(false);
      }
    };

    fetchPages();
  }, [params.chapterId]);

  // Load chapter list for navigation
  useEffect(() => {
    if (!params.id) return;

    const fetchChapters = async () => {
      try {
        const data = await mangaService.getChapters(params.id);
        // Sort ascending by chapter number
        data.sort((a, b) => a.number - b.number);
        setChapters(data);
      } catch (err) {
        console.error("Failed to load chapter list:", err);
      }
    };

    fetchChapters();
  }, [params.id]);

  // Current chapter index in sorted list
  const currentChapterIndex = useMemo(() => {
    return chapters.findIndex(
      (ch) =>
        ch.mangadexChapterId === params.chapterId || ch.id === params.chapterId,
    );
  }, [chapters, params.chapterId]);

  const currentChapter = chapters[currentChapterIndex] ?? null;
  const hasPrevChapter = currentChapterIndex > 0;
  const hasNextChapter =
    currentChapterIndex >= 0 && currentChapterIndex < chapters.length - 1;

  const navigateToChapter = useCallback(
    (chapter: Chapter) => {
      router.push(
        `/manga/${params.id}/chapter/${chapter.mangadexChapterId || chapter.id}`,
      );
    },
    [router, params.id],
  );

  const goToPrevChapter = useCallback(() => {
    if (hasPrevChapter) {
      navigateToChapter(chapters[currentChapterIndex - 1]);
    }
  }, [hasPrevChapter, chapters, currentChapterIndex, navigateToChapter]);

  const goToNextChapter = useCallback(() => {
    if (hasNextChapter) {
      navigateToChapter(chapters[currentChapterIndex + 1]);
    }
  }, [hasNextChapter, chapters, currentChapterIndex, navigateToChapter]);

  const handlePageChange = useCallback((page: number) => {
    setCurrentPage(page);
  }, []);

  const chapterTitle = currentChapter
    ? currentChapter.title
      ? `Ch. ${currentChapter.number} - ${currentChapter.title}`
      : `Chapter ${currentChapter.number}`
    : `Chapter`;

  // Error state
  if (error) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4">
        <svg
          className="h-16 w-16 text-[var(--color-danger)]"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={1.5}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
          />
        </svg>
        <p className="text-[var(--color-danger)]">{error}</p>
        <div className="flex gap-3">
          <button
            onClick={() => window.location.reload()}
            className="rounded-lg bg-[var(--color-primary)] px-4 py-2 text-sm text-white hover:bg-[var(--color-primary-hover)]"
          >
            Retry
          </button>
          <button
            onClick={() => router.push(`/manga/${params.id}`)}
            className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-2 text-sm text-[var(--color-text)] hover:bg-[var(--color-surface-hover)]"
          >
            Back to Manga
          </button>
        </div>
      </div>
    );
  }

  // Loading state
  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="h-12 w-12 animate-spin rounded-full border-3 border-[var(--color-primary)] border-t-transparent" />
          <p className="text-sm text-[var(--color-text-muted)]">
            Loading chapter...
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="relative min-h-screen bg-black">
      {/* Reader Controls */}
      <ReaderControls
        currentPage={currentPage}
        totalPages={pages.length}
        mode={mode}
        onModeChange={setMode}
        onPrevChapter={goToPrevChapter}
        onNextChapter={goToNextChapter}
        hasPrevChapter={hasPrevChapter}
        hasNextChapter={hasNextChapter}
        chapterTitle={chapterTitle}
      />

      {/* Manga Reader */}
      <div className="pt-14 pb-16">
        <MangaReader
          pages={pages}
          mode={mode}
          onPageChange={handlePageChange}
          onChapterEnd={goToNextChapter}
          onChapterPrev={goToPrevChapter}
          className="min-h-[calc(100vh-7.5rem)]"
        />
      </div>

      {/* End-of-chapter card */}
      {currentPage === pages.length - 1 && pages.length > 0 && (
        <div className="flex justify-center pb-20 pt-8">
          <div className="flex flex-col items-center gap-4 rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-8 text-center">
            <p className="text-lg font-semibold text-[var(--color-text)]">
              End of {chapterTitle}
            </p>
            <div className="flex gap-3">
              {hasNextChapter ? (
                <button
                  onClick={goToNextChapter}
                  className="inline-flex items-center gap-2 rounded-xl bg-[var(--color-primary)] px-6 py-3 text-sm font-semibold text-white hover:bg-[var(--color-primary-hover)]"
                >
                  Next Chapter
                  <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                  </svg>
                </button>
              ) : (
                <p className="text-sm text-[var(--color-text-muted)]">
                  You have reached the latest chapter.
                </p>
              )}
              <button
                onClick={() => router.push(`/manga/${params.id}`)}
                className="inline-flex items-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-6 py-3 text-sm font-semibold text-[var(--color-text)] hover:bg-[var(--color-surface-hover)]"
              >
                Back to Manga
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/manga/\[id\]/chapter/\[chapterId\]/page.tsx
git commit -m "feat(web): add chapter reader page with mode persistence and chapter navigation"
```

---

### Task 10: Smoke Test

- [ ] **Step 1: Run type check**

```bash
cd web
npx tsc --noEmit
```

- [ ] **Step 2: Run linter**

```bash
cd web
npm run lint
```

- [ ] **Step 3: Run dev server and verify pages load**

```bash
cd web
npm run dev
```

Verify the following routes:
1. `/manga` — browse page renders, category tabs switch, search works
2. `/manga/[id]` — detail page renders hero + chapter list
3. `/manga/[id]/chapter/[chapterId]` — reader renders with all 3 modes

- [ ] **Step 4: Manual checks**
  - Mode switcher cycles through vertical-scroll, horizontal-swipe, webtoon
  - Horizontal mode responds to arrow keys and click left/right navigation
  - Fullscreen button works
  - Page indicator updates as you scroll/navigate
  - Prev/Next chapter buttons navigate correctly
  - Mode preference persists in localStorage across page navigation
  - Responsive: check at 375px, 768px, 1280px viewports
  - Skeleton loaders appear during data fetches

- [ ] **Step 5: Fix any issues and final commit**

```bash
git add -A
git commit -m "feat(web): phase 3 manga reading — smoke test fixes"
```
