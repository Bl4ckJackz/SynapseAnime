# Phase 4: Movies/TV Browse & Detail + News Feed — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Movies/TV browse and detail pages (TMDB data), stream URL resolution with iframe embed, and a full news feed with categories, search, and trending.

**Architecture:** Service layer calls backend REST endpoints which proxy TMDB. Movie/TV stream URLs are embed URLs (vidsrc) rendered in an iframe. News pages are server-friendly but use client search/filter. All pages follow the existing `(main)` route group layout with dark theme.

**Tech Stack:** Next.js 16, React 19, Tailwind CSS v4, TypeScript

**Prerequisites:** Phases 1-3 complete. `web/services/api-client.ts`, `web/types/movies-tv.ts`, `web/types/news.ts`, `web/lib/utils.ts`, `web/contexts/AuthContext.tsx`, all layout components, and `web/components/ui/*` primitives already exist.

---

## File Structure

```
web/
├── services/
│   ├── movies-tv.service.ts          # TMDB proxy: trending, popular, details, stream
│   └── news.service.ts               # News: list, recent, trending, categories, search
├── components/
│   └── movies/
│       ├─��� MovieCard.tsx              # Poster card for movies
│       ├── TvShowCard.tsx             # Poster card for TV shows
│       └── CastGrid.tsx              # Horizontal scrollable cast list
├── app/
│   └── (main)/
│       ├── movies-tv/
│       │   ├── page.tsx              # Browse: tabs (Movies/TV), trending + popular grids
│       │   ├── movie/
│       │   │   └── [id]/page.tsx     # Movie detail: hero, metadata, cast, similar, Watch
│       │   └── tv/
│       │       └── [id]/page.tsx     # TV detail: hero, seasons accordion, episodes, Watch
│       ���── news/
│           ├── page.tsx              # News list: categories, search bar, trending sidebar
│           └── [id]/page.tsx         # News detail: full article
```

---

### Task 1: Create Movies/TV Service

**Files:**
- Create: `web/services/movies-tv.service.ts`

- [ ] **Step 1: Create `web/services/movies-tv.service.ts`**

```typescript
import { apiClient } from "./api-client";

export interface MovieListItem {
  id: number;
  mediaType: "movie";
  title: string;
  originalTitle?: string;
  description?: string;
  posterUrl: string | null;
  backdropUrl: string | null;
  releaseDate?: string;
  releaseYear: number | null;
  rating: number;
  voteCount: number;
  popularity: number;
  genreIds: number[];
  originalLanguage?: string;
  adult: boolean;
  source: "tmdb";
}

export interface TvListItem {
  id: number;
  mediaType: "tv";
  title: string;
  originalTitle?: string;
  description?: string;
  posterUrl: string | null;
  backdropUrl: string | null;
  firstAirDate?: string;
  releaseYear: number | null;
  rating: number;
  voteCount: number;
  popularity: number;
  genreIds: number[];
  originalLanguage?: string;
  source: "tmdb";
}

export interface Genre {
  id: number;
  name: string;
}

export interface CastMember {
  id: number;
  name: string;
  character?: string;
  profileUrl: string | null;
}

export interface CrewMember {
  id: number;
  name: string;
  job: string;
}

export interface Video {
  id: string;
  key: string;
  name: string;
  type: string;
  site: string;
}

export interface ProductionCompany {
  id: number;
  name: string;
  logoUrl: string | null;
}

export interface MovieDetails {
  id: number;
  mediaType: "movie";
  title: string;
  originalTitle?: string;
  tagline?: string;
  description?: string;
  posterUrl: string | null;
  backdropUrl: string | null;
  releaseDate?: string;
  releaseYear: number | null;
  runtime?: number;
  rating: number;
  voteCount: number;
  popularity: number;
  budget?: number;
  revenue?: number;
  status?: string;
  genres: Genre[];
  productionCompanies: ProductionCompany[];
  cast: CastMember[];
  crew: CrewMember[];
  videos: Video[];
  similar: MovieListItem[];
  recommendations: MovieListItem[];
  originalLanguage?: string;
  spokenLanguages: { iso_639_1: string; name: string }[];
  adult: boolean;
  source: "tmdb";
}

export interface TvSeason {
  id: number;
  seasonNumber: number;
  name: string;
  overview?: string;
  episodeCount: number;
  airDate?: string;
  posterUrl: string | null;
}

export interface TvShowDetails {
  id: number;
  mediaType: "tv";
  title: string;
  originalTitle?: string;
  tagline?: string;
  description?: string;
  posterUrl: string | null;
  backdropUrl: string | null;
  firstAirDate?: string;
  lastAirDate?: string;
  releaseYear: number | null;
  rating: number;
  voteCount: number;
  popularity: number;
  status?: string;
  type?: string;
  numberOfSeasons: number;
  numberOfEpisodes: number;
  episodeRunTime: number[];
  genres: Genre[];
  seasons: TvSeason[];
  networks: { id: number; name: string; logoUrl: string | null }[];
  createdBy: { id: number; name: string; profileUrl: string | null }[];
  cast: CastMember[];
  videos: Video[];
  similar: TvListItem[];
  recommendations: TvListItem[];
  originalLanguage?: string;
  source: "tmdb";
}

export interface TvEpisodeDetails {
  id: number;
  episodeNumber: number;
  seasonNumber: number;
  name: string;
  overview?: string;
  airDate?: string;
  runtime?: number;
  stillUrl: string | null;
  rating: number;
  voteCount: number;
}

export interface SeasonDetails {
  id: number;
  seasonNumber: number;
  name: string;
  overview?: string;
  airDate?: string;
  posterUrl: string | null;
  episodes: TvEpisodeDetails[];
  source: "tmdb";
}

export interface TmdbPagination {
  page: number;
  totalPages: number;
  totalResults: number;
  hasNextPage: boolean;
}

export interface TmdbListResponse<T> {
  data: T[];
  pagination: TmdbPagination;
}

export interface StreamUrlResponse {
  embedUrl: string;
}

export interface SearchResultItem {
  id: number;
  mediaType: "movie" | "tv" | string;
  title: string;
  source: "tmdb";
  // movie fields (optional)
  posterUrl?: string | null;
  backdropUrl?: string | null;
  releaseDate?: string;
  releaseYear?: number | null;
  rating?: number;
  description?: string;
  // tv fields (optional)
  firstAirDate?: string;
}

export const moviesTvService = {
  // --- Search ---
  async search(
    query: string,
    type?: "movie" | "tv",
    page: number = 1,
  ): Promise<TmdbListResponse<SearchResultItem>> {
    return apiClient.get<TmdbListResponse<SearchResultItem>>(
      "/movies-tv/search",
      { q: query, type, page },
    );
  },

  // --- Movies ---
  async getTrendingMovies(
    page: number = 1,
  ): Promise<TmdbListResponse<MovieListItem>> {
    return apiClient.get<TmdbListResponse<MovieListItem>>(
      "/movies-tv/movies/trending",
      { page },
    );
  },

  async getPopularMovies(
    page: number = 1,
  ): Promise<TmdbListResponse<MovieListItem>> {
    return apiClient.get<TmdbListResponse<MovieListItem>>(
      "/movies-tv/movies/popular",
      { page },
    );
  },

  async getMovieDetails(id: number): Promise<MovieDetails> {
    return apiClient.get<MovieDetails>(`/movies-tv/movies/${id}`);
  },

  async getMovieStreamUrl(tmdbId: number): Promise<StreamUrlResponse> {
    return apiClient.get<StreamUrlResponse>(
      `/movies-tv/stream/movie/${tmdbId}`,
    );
  },

  // --- TV Shows ---
  async getTrendingTvShows(
    page: number = 1,
  ): Promise<TmdbListResponse<TvListItem>> {
    return apiClient.get<TmdbListResponse<TvListItem>>(
      "/movies-tv/tv/trending",
      { page },
    );
  },

  async getPopularTvShows(
    page: number = 1,
  ): Promise<TmdbListResponse<TvListItem>> {
    return apiClient.get<TmdbListResponse<TvListItem>>(
      "/movies-tv/tv/popular",
      { page },
    );
  },

  async getTvShowDetails(id: number): Promise<TvShowDetails> {
    return apiClient.get<TvShowDetails>(`/movies-tv/tv/${id}`);
  },

  async getSeasonDetails(
    tvId: number,
    seasonNumber: number,
  ): Promise<SeasonDetails> {
    return apiClient.get<SeasonDetails>(
      `/movies-tv/tv/${tvId}/season/${seasonNumber}`,
    );
  },

  async getTvStreamUrl(
    tmdbId: number,
    season: number,
    episode: number,
  ): Promise<StreamUrlResponse> {
    return apiClient.get<StreamUrlResponse>(
      `/movies-tv/stream/tv/${tmdbId}/${season}/${episode}`,
    );
  },
};
```

- [ ] **Step 2: Commit**

```bash
git add web/services/movies-tv.service.ts
git commit -m "feat(web): add movies-tv service layer with TMDB proxy calls"
```

---

### Task 2: Create News Service

**Files:**
- Create: `web/services/news.service.ts`

- [ ] **Step 1: Create `web/services/news.service.ts`**

```typescript
import { apiClient } from "./api-client";

export interface NewsItem {
  id: string;
  source: "myanimelist" | "anilist" | "custom";
  sourceId?: string;
  title: string;
  content: string;
  excerpt: string;
  coverImage?: string;
  category: string;
  tags: string[];
  publishedAt: string;
  externalUrl?: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export const newsService = {
  async getNews(params?: {
    sources?: string;
    category?: string;
    limit?: number;
    search?: string;
  }): Promise<NewsItem[]> {
    return apiClient.get<NewsItem[]>("/news", {
      sources: params?.sources,
      category: params?.category,
      limit: params?.limit,
      search: params?.search,
    });
  },

  async getRecent(limit: number = 10): Promise<NewsItem[]> {
    return apiClient.get<NewsItem[]>("/news/recent", { limit });
  },

  async getTrending(limit: number = 5): Promise<NewsItem[]> {
    return apiClient.get<NewsItem[]>("/news/trending", { limit });
  },

  async getByCategory(
    category: string,
    limit: number = 10,
  ): Promise<NewsItem[]> {
    return apiClient.get<NewsItem[]>(`/news/category/${category}`, { limit });
  },

  async search(query: string, limit: number = 10): Promise<NewsItem[]> {
    return apiClient.get<NewsItem[]>(`/news/search/${encodeURIComponent(query)}`, {
      limit,
    });
  },

  async getById(id: string): Promise<NewsItem> {
    return apiClient.get<NewsItem>(`/news/${id}`);
  },
};
```

- [ ] **Step 2: Commit**

```bash
git add web/services/news.service.ts
git commit -m "feat(web): add news service with category/search/trending"
```

---

### Task 3: Create MovieCard and TvShowCard Components

**Files:**
- Create: `web/components/movies/MovieCard.tsx`
- Create: `web/components/movies/TvShowCard.tsx`

- [ ] **Step 1: Create `web/components/movies/MovieCard.tsx`**

```tsx
"use client";

import Image from "next/image";
import Link from "next/link";
import type { MovieListItem } from "@/services/movies-tv.service";

interface MovieCardProps {
  movie: MovieListItem;
}

export function MovieCard({ movie }: MovieCardProps) {
  return (
    <Link
      href={`/movies-tv/movie/${movie.id}`}
      className="group flex flex-col gap-2"
    >
      <div className="relative aspect-[2/3] overflow-hidden rounded-lg bg-[var(--color-surface)]">
        {movie.posterUrl ? (
          <Image
            src={movie.posterUrl}
            alt={movie.title}
            fill
            sizes="(max-width: 640px) 45vw, (max-width: 1024px) 22vw, 185px"
            className="object-cover transition-transform duration-300 group-hover:scale-105"
          />
        ) : (
          <div className="flex h-full items-center justify-center text-[var(--color-text-muted)] text-sm">
            No Image
          </div>
        )}

        {/* Rating badge */}
        <div className="absolute top-2 left-2 flex items-center gap-1 rounded-md bg-black/70 px-1.5 py-0.5 text-xs font-semibold text-yellow-400">
          <svg
            className="h-3 w-3 fill-yellow-400"
            viewBox="0 0 20 20"
          >
            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
          </svg>
          {movie.rating.toFixed(1)}
        </div>
      </div>

      <div className="flex flex-col gap-0.5 px-0.5">
        <h3 className="text-sm font-medium text-[var(--color-text)] line-clamp-2 group-hover:text-[var(--color-primary)] transition-colors">
          {movie.title}
        </h3>
        {movie.releaseYear && (
          <span className="text-xs text-[var(--color-text-muted)]">
            {movie.releaseYear}
          </span>
        )}
      </div>
    </Link>
  );
}
```

- [ ] **Step 2: Create `web/components/movies/TvShowCard.tsx`**

```tsx
"use client";

import Image from "next/image";
import Link from "next/link";
import type { TvListItem } from "@/services/movies-tv.service";

interface TvShowCardProps {
  show: TvListItem;
}

export function TvShowCard({ show }: TvShowCardProps) {
  return (
    <Link
      href={`/movies-tv/tv/${show.id}`}
      className="group flex flex-col gap-2"
    >
      <div className="relative aspect-[2/3] overflow-hidden rounded-lg bg-[var(--color-surface)]">
        {show.posterUrl ? (
          <Image
            src={show.posterUrl}
            alt={show.title}
            fill
            sizes="(max-width: 640px) 45vw, (max-width: 1024px) 22vw, 185px"
            className="object-cover transition-transform duration-300 group-hover:scale-105"
          />
        ) : (
          <div className="flex h-full items-center justify-center text-[var(--color-text-muted)] text-sm">
            No Image
          </div>
        )}

        {/* Rating badge */}
        <div className="absolute top-2 left-2 flex items-center gap-1 rounded-md bg-black/70 px-1.5 py-0.5 text-xs font-semibold text-yellow-400">
          <svg
            className="h-3 w-3 fill-yellow-400"
            viewBox="0 0 20 20"
          >
            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
          </svg>
          {show.rating.toFixed(1)}
        </div>
      </div>

      <div className="flex flex-col gap-0.5 px-0.5">
        <h3 className="text-sm font-medium text-[var(--color-text)] line-clamp-2 group-hover:text-[var(--color-primary)] transition-colors">
          {show.title}
        </h3>
        {show.releaseYear && (
          <span className="text-xs text-[var(--color-text-muted)]">
            {show.releaseYear}
          </span>
        )}
      </div>
    </Link>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add web/components/movies/MovieCard.tsx web/components/movies/TvShowCard.tsx
git commit -m "feat(web): add MovieCard and TvShowCard components"
```

---

### Task 4: Create CastGrid Component

**Files:**
- Create: `web/components/movies/CastGrid.tsx`

- [ ] **Step 1: Create `web/components/movies/CastGrid.tsx`**

```tsx
"use client";

import Image from "next/image";
import type { CastMember } from "@/services/movies-tv.service";

interface CastGridProps {
  cast: CastMember[];
  maxVisible?: number;
}

export function CastGrid({ cast, maxVisible = 20 }: CastGridProps) {
  const visible = cast.slice(0, maxVisible);

  if (visible.length === 0) return null;

  return (
    <section>
      <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
        Cast
      </h2>
      <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-thin">
        {visible.map((member) => (
          <div
            key={`${member.id}-${member.character}`}
            className="flex flex-col items-center gap-1.5 shrink-0 w-24"
          >
            <div className="relative h-24 w-24 overflow-hidden rounded-full bg-[var(--color-surface)]">
              {member.profileUrl ? (
                <Image
                  src={member.profileUrl}
                  alt={member.name}
                  fill
                  sizes="96px"
                  className="object-cover"
                />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-2xl font-bold text-[var(--color-text-muted)]">
                  {member.name.charAt(0)}
                </div>
              )}
            </div>
            <div className="text-center w-full">
              <p className="text-xs font-medium text-[var(--color-text)] line-clamp-1">
                {member.name}
              </p>
              {member.character && (
                <p className="text-[10px] text-[var(--color-text-muted)] line-clamp-1">
                  {member.character}
                </p>
              )}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/movies/CastGrid.tsx
git commit -m "feat(web): add CastGrid component for movie/tv detail pages"
```

---

### Task 5: Create Movies/TV Browse Page

**Files:**
- Create: `web/app/(main)/movies-tv/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/movies-tv/page.tsx`**

```tsx
"use client";

import { useEffect, useState, useCallback } from "react";
import {
  moviesTvService,
  type MovieListItem,
  type TvListItem,
  type SearchResultItem,
} from "@/services/movies-tv.service";
import { MovieCard } from "@/components/movies/MovieCard";
import { TvShowCard } from "@/components/movies/TvShowCard";
import { Skeleton } from "@/components/ui/Skeleton";

type Tab = "movies" | "tv";

export default function MoviesTvPage() {
  const [activeTab, setActiveTab] = useState<Tab>("movies");
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<SearchResultItem[]>([]);
  const [isSearching, setIsSearching] = useState(false);

  // Movies state
  const [trendingMovies, setTrendingMovies] = useState<MovieListItem[]>([]);
  const [popularMovies, setPopularMovies] = useState<MovieListItem[]>([]);
  const [moviesLoading, setMoviesLoading] = useState(true);

  // TV state
  const [trendingTv, setTrendingTv] = useState<TvListItem[]>([]);
  const [popularTv, setPopularTv] = useState<TvListItem[]>([]);
  const [tvLoading, setTvLoading] = useState(true);

  // Fetch movies
  useEffect(() => {
    let cancelled = false;
    setMoviesLoading(true);

    Promise.all([
      moviesTvService.getTrendingMovies(),
      moviesTvService.getPopularMovies(),
    ])
      .then(([trending, popular]) => {
        if (cancelled) return;
        setTrendingMovies(trending.data);
        setPopularMovies(popular.data);
      })
      .catch((err) => {
        if (!cancelled) console.error("Failed to load movies:", err);
      })
      .finally(() => {
        if (!cancelled) setMoviesLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  // Fetch TV shows
  useEffect(() => {
    let cancelled = false;
    setTvLoading(true);

    Promise.all([
      moviesTvService.getTrendingTvShows(),
      moviesTvService.getPopularTvShows(),
    ])
      .then(([trending, popular]) => {
        if (cancelled) return;
        setTrendingTv(trending.data);
        setPopularTv(popular.data);
      })
      .catch((err) => {
        if (!cancelled) console.error("Failed to load TV shows:", err);
      })
      .finally(() => {
        if (!cancelled) setTvLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  // Search handler with debounce
  const handleSearch = useCallback(
    async (query: string) => {
      setSearchQuery(query);
      if (!query.trim()) {
        setSearchResults([]);
        setIsSearching(false);
        return;
      }

      setIsSearching(true);
      try {
        const type = activeTab === "movies" ? "movie" : "tv";
        const res = await moviesTvService.search(query, type);
        setSearchResults(res.data);
      } catch (err) {
        console.error("Search failed:", err);
      } finally {
        setIsSearching(false);
      }
    },
    [activeTab],
  );

  // Debounce input
  useEffect(() => {
    if (!searchQuery.trim()) return;
    const timer = setTimeout(() => handleSearch(searchQuery), 400);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchQuery]);

  const isLoading = activeTab === "movies" ? moviesLoading : tvLoading;

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <h1 className="text-2xl font-bold text-[var(--color-text)]">
          Movies & TV
        </h1>

        {/* Search */}
        <div className="relative w-full sm:w-80">
          <input
            type="text"
            placeholder={`Search ${activeTab === "movies" ? "movies" : "TV shows"}...`}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-2 pl-10 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] outline-none focus:border-[var(--color-primary)] transition-colors"
          />
          <svg
            className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-text-muted)]"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 rounded-lg bg-[var(--color-surface)] p-1 w-fit">
        <button
          onClick={() => {
            setActiveTab("movies");
            setSearchQuery("");
            setSearchResults([]);
          }}
          className={`rounded-md px-4 py-1.5 text-sm font-medium transition-colors ${
            activeTab === "movies"
              ? "bg-[var(--color-primary)] text-white"
              : "text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
          }`}
        >
          Movies
        </button>
        <button
          onClick={() => {
            setActiveTab("tv");
            setSearchQuery("");
            setSearchResults([]);
          }}
          className={`rounded-md px-4 py-1.5 text-sm font-medium transition-colors ${
            activeTab === "tv"
              ? "bg-[var(--color-primary)] text-white"
              : "text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
          }`}
        >
          TV Shows
        </button>
      </div>

      {/* Search Results */}
      {searchQuery.trim() && (
        <section>
          <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
            Search Results
          </h2>
          {isSearching ? (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
              {Array.from({ length: 12 }).map((_, i) => (
                <Skeleton key={i} className="aspect-[2/3] rounded-lg" />
              ))}
            </div>
          ) : searchResults.length === 0 ? (
            <p className="text-[var(--color-text-muted)]">
              No results found for &ldquo;{searchQuery}&rdquo;
            </p>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
              {searchResults.map((item) =>
                item.mediaType === "movie" ? (
                  <MovieCard key={item.id} movie={item as unknown as MovieListItem} />
                ) : (
                  <TvShowCard key={item.id} show={item as unknown as TvListItem} />
                ),
              )}
            </div>
          )}
        </section>
      )}

      {/* Content (shown when not searching) */}
      {!searchQuery.trim() && (
        <>
          {activeTab === "movies" ? (
            <>
              {/* Trending Movies */}
              <section>
                <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
                  Trending Movies
                </h2>
                {isLoading ? (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {Array.from({ length: 12 }).map((_, i) => (
                      <Skeleton key={i} className="aspect-[2/3] rounded-lg" />
                    ))}
                  </div>
                ) : (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {trendingMovies.map((movie) => (
                      <MovieCard key={movie.id} movie={movie} />
                    ))}
                  </div>
                )}
              </section>

              {/* Popular Movies */}
              <section>
                <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
                  Popular Movies
                </h2>
                {isLoading ? (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {Array.from({ length: 12 }).map((_, i) => (
                      <Skeleton key={i} className="aspect-[2/3] rounded-lg" />
                    ))}
                  </div>
                ) : (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {popularMovies.map((movie) => (
                      <MovieCard key={movie.id} movie={movie} />
                    ))}
                  </div>
                )}
              </section>
            </>
          ) : (
            <>
              {/* Trending TV */}
              <section>
                <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
                  Trending TV Shows
                </h2>
                {isLoading ? (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {Array.from({ length: 12 }).map((_, i) => (
                      <Skeleton key={i} className="aspect-[2/3] rounded-lg" />
                    ))}
                  </div>
                ) : (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {trendingTv.map((show) => (
                      <TvShowCard key={show.id} show={show} />
                    ))}
                  </div>
                )}
              </section>

              {/* Popular TV */}
              <section>
                <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
                  Popular TV Shows
                </h2>
                {isLoading ? (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {Array.from({ length: 12 }).map((_, i) => (
                      <Skeleton key={i} className="aspect-[2/3] rounded-lg" />
                    ))}
                  </div>
                ) : (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                    {popularTv.map((show) => (
                      <TvShowCard key={show.id} show={show} />
                    ))}
                  </div>
                )}
              </section>
            </>
          )}
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/movies-tv/page.tsx
git commit -m "feat(web): add movies-tv browse page with tabs, trending, popular, search"
```

---

### Task 6: Create Movie Detail Page

**Files:**
- Create: `web/app/(main)/movies-tv/movie/[id]/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/movies-tv/movie/[id]/page.tsx`**

```tsx
"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Image from "next/image";
import Link from "next/link";
import {
  moviesTvService,
  type MovieDetails,
} from "@/services/movies-tv.service";
import { CastGrid } from "@/components/movies/CastGrid";
import { MovieCard } from "@/components/movies/MovieCard";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate } from "@/lib/utils";

export default function MovieDetailPage() {
  const params = useParams();
  const id = Number(params.id);

  const [movie, setMovie] = useState<MovieDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Stream state
  const [streamUrl, setStreamUrl] = useState<string | null>(null);
  const [streamLoading, setStreamLoading] = useState(false);
  const [showPlayer, setShowPlayer] = useState(false);

  useEffect(() => {
    if (!id || isNaN(id)) return;

    let cancelled = false;
    setLoading(true);
    setError(null);

    moviesTvService
      .getMovieDetails(id)
      .then((data) => {
        if (!cancelled) setMovie(data);
      })
      .catch((err) => {
        if (!cancelled) setError(err?.message || "Failed to load movie");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [id]);

  const handleWatch = async () => {
    if (!movie) return;
    setStreamLoading(true);

    try {
      const { embedUrl } = await moviesTvService.getMovieStreamUrl(movie.id);
      setStreamUrl(embedUrl);
      setShowPlayer(true);
    } catch (err) {
      console.error("Failed to get stream URL:", err);
      setError("Failed to load stream. Please try again.");
    } finally {
      setStreamLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col gap-6 p-4 sm:p-6">
        <Skeleton className="h-[400px] w-full rounded-xl" />
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-4 w-full max-w-2xl" />
        <Skeleton className="h-4 w-full max-w-xl" />
      </div>
    );
  }

  if (error || !movie) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 p-12">
        <p className="text-[var(--color-danger)] text-lg">
          {error || "Movie not found"}
        </p>
        <Link
          href="/movies-tv"
          className="text-[var(--color-primary)] hover:underline"
        >
          Back to Movies & TV
        </Link>
      </div>
    );
  }

  const director = movie.crew.find((c) => c.job === "Director");

  return (
    <div className="flex flex-col gap-8">
      {/* Hero Section */}
      <div className="relative w-full">
        {/* Backdrop */}
        {movie.backdropUrl && (
          <div className="relative h-[300px] sm:h-[400px] lg:h-[500px] w-full">
            <Image
              src={movie.backdropUrl}
              alt={movie.title}
              fill
              priority
              className="object-cover"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-[var(--color-bg)] via-[var(--color-bg)]/60 to-transparent" />
          </div>
        )}

        {/* Info overlay */}
        <div
          className={`${movie.backdropUrl ? "absolute bottom-0 left-0 right-0" : ""} flex flex-col sm:flex-row gap-6 p-4 sm:p-6`}
        >
          {/* Poster */}
          {movie.posterUrl && (
            <div className="relative hidden sm:block h-[270px] w-[180px] shrink-0 overflow-hidden rounded-lg shadow-2xl">
              <Image
                src={movie.posterUrl}
                alt={movie.title}
                fill
                sizes="180px"
                className="object-cover"
              />
            </div>
          )}

          <div className="flex flex-col gap-3">
            <h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold text-white drop-shadow-lg">
              {movie.title}
              {movie.releaseYear && (
                <span className="ml-2 text-lg font-normal text-white/70">
                  ({movie.releaseYear})
                </span>
              )}
            </h1>

            {movie.tagline && (
              <p className="text-sm italic text-white/70">{movie.tagline}</p>
            )}

            {/* Metadata row */}
            <div className="flex flex-wrap items-center gap-3 text-sm text-white/80">
              {movie.releaseDate && (
                <span>{formatDate(movie.releaseDate)}</span>
              )}
              {movie.runtime && (
                <>
                  <span className="text-white/40">|</span>
                  <span>{Math.floor(movie.runtime / 60)}h {movie.runtime % 60}m</span>
                </>
              )}
              <span className="text-white/40">|</span>
              <span className="flex items-center gap-1 text-yellow-400 font-semibold">
                <svg className="h-4 w-4 fill-yellow-400" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                {movie.rating.toFixed(1)}
              </span>
              <span className="text-white/50 text-xs">
                ({movie.voteCount.toLocaleString()} votes)
              </span>
            </div>

            {/* Genres */}
            <div className="flex flex-wrap gap-2">
              {movie.genres.map((genre) => (
                <span
                  key={genre.id}
                  className="rounded-full bg-white/10 px-3 py-0.5 text-xs text-white/90"
                >
                  {genre.name}
                </span>
              ))}
            </div>

            {/* Watch button */}
            <button
              onClick={handleWatch}
              disabled={streamLoading}
              className="mt-2 flex w-fit items-center gap-2 rounded-lg bg-[var(--color-primary)] px-6 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-[var(--color-primary-hover)] disabled:opacity-50"
            >
              {streamLoading ? (
                <>
                  <svg
                    className="h-4 w-4 animate-spin"
                    viewBox="0 0 24 24"
                    fill="none"
                  >
                    <circle
                      className="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      strokeWidth="4"
                    />
                    <path
                      className="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                    />
                  </svg>
                  Loading...
                </>
              ) : (
                <>
                  <svg
                    className="h-5 w-5 fill-white"
                    viewBox="0 0 24 24"
                  >
                    <path d="M8 5v14l11-7z" />
                  </svg>
                  Watch Movie
                </>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Video Player (iframe embed) */}
      {showPlayer && streamUrl && (
        <section className="px-4 sm:px-6">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-lg font-semibold text-[var(--color-text)]">
              Now Playing
            </h2>
            <button
              onClick={() => {
                setShowPlayer(false);
                setStreamUrl(null);
              }}
              className="text-sm text-[var(--color-text-muted)] hover:text-[var(--color-text)] transition-colors"
            >
              Close Player
            </button>
          </div>
          <div className="relative w-full overflow-hidden rounded-xl bg-black" style={{ paddingBottom: "56.25%" }}>
            <iframe
              src={streamUrl}
              className="absolute inset-0 h-full w-full"
              allowFullScreen
              allow="autoplay; encrypted-media; picture-in-picture"
              referrerPolicy="origin"
              sandbox="allow-scripts allow-same-origin allow-forms allow-popups"
            />
          </div>
        </section>
      )}

      {/* Content */}
      <div className="flex flex-col gap-8 px-4 sm:px-6 pb-8">
        {/* Overview */}
        {movie.description && (
          <section>
            <h2 className="mb-2 text-lg font-semibold text-[var(--color-text)]">
              Overview
            </h2>
            <p className="text-sm leading-relaxed text-[var(--color-text-muted)]">
              {movie.description}
            </p>
          </section>
        )}

        {/* Details grid */}
        <section className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 text-sm">
          {director && (
            <div>
              <span className="text-[var(--color-text-muted)]">Director</span>
              <p className="font-medium text-[var(--color-text)]">
                {director.name}
              </p>
            </div>
          )}
          {movie.status && (
            <div>
              <span className="text-[var(--color-text-muted)]">Status</span>
              <p className="font-medium text-[var(--color-text)]">
                {movie.status}
              </p>
            </div>
          )}
          {movie.budget && movie.budget > 0 && (
            <div>
              <span className="text-[var(--color-text-muted)]">Budget</span>
              <p className="font-medium text-[var(--color-text)]">
                ${movie.budget.toLocaleString()}
              </p>
            </div>
          )}
          {movie.revenue && movie.revenue > 0 && (
            <div>
              <span className="text-[var(--color-text-muted)]">Revenue</span>
              <p className="font-medium text-[var(--color-text)]">
                ${movie.revenue.toLocaleString()}
              </p>
            </div>
          )}
          {movie.originalLanguage && (
            <div>
              <span className="text-[var(--color-text-muted)]">Language</span>
              <p className="font-medium text-[var(--color-text)] uppercase">
                {movie.originalLanguage}
              </p>
            </div>
          )}
        </section>

        {/* Trailer */}
        {movie.videos.length > 0 && (
          <section>
            <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
              Trailer
            </h2>
            <div className="relative w-full max-w-2xl overflow-hidden rounded-xl bg-black" style={{ paddingBottom: "min(56.25%, 360px)" }}>
              <iframe
                src={`https://www.youtube.com/embed/${movie.videos[0].key}`}
                className="absolute inset-0 h-full w-full"
                allowFullScreen
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              />
            </div>
          </section>
        )}

        {/* Cast */}
        <CastGrid cast={movie.cast} />

        {/* Similar Movies */}
        {movie.similar.length > 0 && (
          <section>
            <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
              Similar Movies
            </h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
              {movie.similar.map((m) => (
                <MovieCard key={m.id} movie={m} />
              ))}
            </div>
          </section>
        )}

        {/* Recommendations */}
        {movie.recommendations.length > 0 && (
          <section>
            <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
              Recommended
            </h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
              {movie.recommendations.map((m) => (
                <MovieCard key={m.id} movie={m} />
              ))}
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/movies-tv/movie/\[id\]/page.tsx
git commit -m "feat(web): add movie detail page with hero, cast, trailer, stream embed"
```

---

### Task 7: Create TV Show Detail Page

**Files:**
- Create: `web/app/(main)/movies-tv/tv/[id]/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/movies-tv/tv/[id]/page.tsx`**

```tsx
"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams } from "next/navigation";
import Image from "next/image";
import Link from "next/link";
import {
  moviesTvService,
  type TvShowDetails,
  type SeasonDetails,
  type TvEpisodeDetails,
} from "@/services/movies-tv.service";
import { CastGrid } from "@/components/movies/CastGrid";
import { TvShowCard } from "@/components/movies/TvShowCard";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate } from "@/lib/utils";

export default function TvShowDetailPage() {
  const params = useParams();
  const id = Number(params.id);

  const [show, setShow] = useState<TvShowDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Season accordion state
  const [expandedSeason, setExpandedSeason] = useState<number | null>(null);
  const [seasonData, setSeasonData] = useState<Record<number, SeasonDetails>>(
    {},
  );
  const [seasonLoading, setSeasonLoading] = useState<number | null>(null);

  // Stream state
  const [streamUrl, setStreamUrl] = useState<string | null>(null);
  const [streamLoading, setStreamLoading] = useState<string | null>(null); // "S1E2" key
  const [showPlayer, setShowPlayer] = useState(false);
  const [activeEpisodeLabel, setActiveEpisodeLabel] = useState("");

  // Fetch show details
  useEffect(() => {
    if (!id || isNaN(id)) return;

    let cancelled = false;
    setLoading(true);
    setError(null);

    moviesTvService
      .getTvShowDetails(id)
      .then((data) => {
        if (!cancelled) setShow(data);
      })
      .catch((err) => {
        if (!cancelled) setError(err?.message || "Failed to load TV show");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [id]);

  // Toggle season accordion
  const toggleSeason = useCallback(
    async (seasonNumber: number) => {
      if (expandedSeason === seasonNumber) {
        setExpandedSeason(null);
        return;
      }

      setExpandedSeason(seasonNumber);

      if (seasonData[seasonNumber]) return;

      setSeasonLoading(seasonNumber);
      try {
        const data = await moviesTvService.getSeasonDetails(id, seasonNumber);
        setSeasonData((prev) => ({ ...prev, [seasonNumber]: data }));
      } catch (err) {
        console.error(`Failed to load season ${seasonNumber}:`, err);
      } finally {
        setSeasonLoading(null);
      }
    },
    [id, expandedSeason, seasonData],
  );

  // Stream episode
  const handleStreamEpisode = async (
    episode: TvEpisodeDetails,
  ) => {
    if (!show) return;
    const key = `S${episode.seasonNumber}E${episode.episodeNumber}`;
    setStreamLoading(key);

    try {
      const { embedUrl } = await moviesTvService.getTvStreamUrl(
        show.id,
        episode.seasonNumber,
        episode.episodeNumber,
      );
      setStreamUrl(embedUrl);
      setActiveEpisodeLabel(`S${episode.seasonNumber} E${episode.episodeNumber} - ${episode.name}`);
      setShowPlayer(true);
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (err) {
      console.error("Failed to get stream URL:", err);
    } finally {
      setStreamLoading(null);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col gap-6 p-4 sm:p-6">
        <Skeleton className="h-[400px] w-full rounded-xl" />
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-4 w-full max-w-2xl" />
      </div>
    );
  }

  if (error || !show) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 p-12">
        <p className="text-[var(--color-danger)] text-lg">
          {error || "TV show not found"}
        </p>
        <Link
          href="/movies-tv"
          className="text-[var(--color-primary)] hover:underline"
        >
          Back to Movies & TV
        </Link>
      </div>
    );
  }

  // Filter out specials (season 0) for main display, keep them accessible
  const mainSeasons = show.seasons.filter((s) => s.seasonNumber > 0);
  const specialsSeason = show.seasons.find((s) => s.seasonNumber === 0);

  return (
    <div className="flex flex-col gap-8">
      {/* Video Player (iframe embed) */}
      {showPlayer && streamUrl && (
        <section className="px-4 sm:px-6 pt-4">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-lg font-semibold text-[var(--color-text)]">
              Now Playing: {activeEpisodeLabel}
            </h2>
            <button
              onClick={() => {
                setShowPlayer(false);
                setStreamUrl(null);
                setActiveEpisodeLabel("");
              }}
              className="text-sm text-[var(--color-text-muted)] hover:text-[var(--color-text)] transition-colors"
            >
              Close Player
            </button>
          </div>
          <div
            className="relative w-full overflow-hidden rounded-xl bg-black"
            style={{ paddingBottom: "56.25%" }}
          >
            <iframe
              src={streamUrl}
              className="absolute inset-0 h-full w-full"
              allowFullScreen
              allow="autoplay; encrypted-media; picture-in-picture"
              referrerPolicy="origin"
              sandbox="allow-scripts allow-same-origin allow-forms allow-popups"
            />
          </div>
        </section>
      )}

      {/* Hero Section */}
      <div className="relative w-full">
        {show.backdropUrl && (
          <div className="relative h-[300px] sm:h-[400px] lg:h-[500px] w-full">
            <Image
              src={show.backdropUrl}
              alt={show.title}
              fill
              priority
              className="object-cover"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-[var(--color-bg)] via-[var(--color-bg)]/60 to-transparent" />
          </div>
        )}

        <div
          className={`${show.backdropUrl ? "absolute bottom-0 left-0 right-0" : ""} flex flex-col sm:flex-row gap-6 p-4 sm:p-6`}
        >
          {show.posterUrl && (
            <div className="relative hidden sm:block h-[270px] w-[180px] shrink-0 overflow-hidden rounded-lg shadow-2xl">
              <Image
                src={show.posterUrl}
                alt={show.title}
                fill
                sizes="180px"
                className="object-cover"
              />
            </div>
          )}

          <div className="flex flex-col gap-3">
            <h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold text-white drop-shadow-lg">
              {show.title}
              {show.releaseYear && (
                <span className="ml-2 text-lg font-normal text-white/70">
                  ({show.releaseYear})
                </span>
              )}
            </h1>

            {show.tagline && (
              <p className="text-sm italic text-white/70">{show.tagline}</p>
            )}

            <div className="flex flex-wrap items-center gap-3 text-sm text-white/80">
              {show.firstAirDate && (
                <span>{formatDate(show.firstAirDate)}</span>
              )}
              <span className="text-white/40">|</span>
              <span>
                {show.numberOfSeasons} Season{show.numberOfSeasons !== 1 ? "s" : ""}
              </span>
              <span className="text-white/40">|</span>
              <span>
                {show.numberOfEpisodes} Episode{show.numberOfEpisodes !== 1 ? "s" : ""}
              </span>
              <span className="text-white/40">|</span>
              <span className="flex items-center gap-1 text-yellow-400 font-semibold">
                <svg className="h-4 w-4 fill-yellow-400" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                {show.rating.toFixed(1)}
              </span>
              {show.status && (
                <>
                  <span className="text-white/40">|</span>
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      show.status === "Returning Series"
                        ? "bg-green-500/20 text-green-400"
                        : show.status === "Ended"
                          ? "bg-red-500/20 text-red-400"
                          : "bg-blue-500/20 text-blue-400"
                    }`}
                  >
                    {show.status}
                  </span>
                </>
              )}
            </div>

            <div className="flex flex-wrap gap-2">
              {show.genres.map((genre) => (
                <span
                  key={genre.id}
                  className="rounded-full bg-white/10 px-3 py-0.5 text-xs text-white/90"
                >
                  {genre.name}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex flex-col gap-8 px-4 sm:px-6 pb-8">
        {/* Overview */}
        {show.description && (
          <section>
            <h2 className="mb-2 text-lg font-semibold text-[var(--color-text)]">
              Overview
            </h2>
            <p className="text-sm leading-relaxed text-[var(--color-text-muted)]">
              {show.description}
            </p>
          </section>
        )}

        {/* Info grid */}
        <section className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4 text-sm">
          {show.createdBy.length > 0 && (
            <div>
              <span className="text-[var(--color-text-muted)]">Created By</span>
              <p className="font-medium text-[var(--color-text)]">
                {show.createdBy.map((c) => c.name).join(", ")}
              </p>
            </div>
          )}
          {show.networks.length > 0 && (
            <div>
              <span className="text-[var(--color-text-muted)]">Network</span>
              <p className="font-medium text-[var(--color-text)]">
                {show.networks.map((n) => n.name).join(", ")}
              </p>
            </div>
          )}
          {show.type && (
            <div>
              <span className="text-[var(--color-text-muted)]">Type</span>
              <p className="font-medium text-[var(--color-text)]">{show.type}</p>
            </div>
          )}
          {show.originalLanguage && (
            <div>
              <span className="text-[var(--color-text-muted)]">Language</span>
              <p className="font-medium text-[var(--color-text)] uppercase">
                {show.originalLanguage}
              </p>
            </div>
          )}
        </section>

        {/* Trailer */}
        {show.videos.length > 0 && (
          <section>
            <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
              Trailer
            </h2>
            <div
              className="relative w-full max-w-2xl overflow-hidden rounded-xl bg-black"
              style={{ paddingBottom: "min(56.25%, 360px)" }}
            >
              <iframe
                src={`https://www.youtube.com/embed/${show.videos[0].key}`}
                className="absolute inset-0 h-full w-full"
                allowFullScreen
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              />
            </div>
          </section>
        )}

        {/* Cast */}
        <CastGrid cast={show.cast} />

        {/* Seasons Accordion */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
            Seasons & Episodes
          </h2>

          <div className="flex flex-col gap-2">
            {mainSeasons.map((season) => {
              const isExpanded = expandedSeason === season.seasonNumber;
              const episodes = seasonData[season.seasonNumber]?.episodes || [];
              const isLoadingSeason = seasonLoading === season.seasonNumber;

              return (
                <div
                  key={season.id}
                  className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden"
                >
                  {/* Season header */}
                  <button
                    onClick={() => toggleSeason(season.seasonNumber)}
                    className="flex w-full items-center justify-between px-4 py-3 text-left transition-colors hover:bg-[var(--color-surface-hover)]"
                  >
                    <div className="flex items-center gap-3">
                      {season.posterUrl && (
                        <div className="relative h-12 w-8 shrink-0 overflow-hidden rounded">
                          <Image
                            src={season.posterUrl}
                            alt={season.name}
                            fill
                            sizes="32px"
                            className="object-cover"
                          />
                        </div>
                      )}
                      <div>
                        <h3 className="text-sm font-medium text-[var(--color-text)]">
                          {season.name}
                        </h3>
                        <p className="text-xs text-[var(--color-text-muted)]">
                          {season.episodeCount} episode{season.episodeCount !== 1 ? "s" : ""}
                          {season.airDate && ` - ${formatDate(season.airDate)}`}
                        </p>
                      </div>
                    </div>
                    <svg
                      className={`h-5 w-5 text-[var(--color-text-muted)] transition-transform duration-200 ${
                        isExpanded ? "rotate-180" : ""
                      }`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M19 9l-7 7-7-7"
                      />
                    </svg>
                  </button>

                  {/* Episodes list */}
                  {isExpanded && (
                    <div className="border-t border-[var(--color-border)]">
                      {isLoadingSeason ? (
                        <div className="flex flex-col gap-2 p-4">
                          {Array.from({ length: 3 }).map((_, i) => (
                            <Skeleton key={i} className="h-16 w-full rounded-md" />
                          ))}
                        </div>
                      ) : episodes.length === 0 ? (
                        <p className="p-4 text-sm text-[var(--color-text-muted)]">
                          No episodes available
                        </p>
                      ) : (
                        <div className="divide-y divide-[var(--color-border)]">
                          {episodes.map((ep) => {
                            const epKey = `S${ep.seasonNumber}E${ep.episodeNumber}`;
                            const isStreamLoading = streamLoading === epKey;

                            return (
                              <div
                                key={ep.id}
                                className="flex items-start gap-3 p-3 transition-colors hover:bg-[var(--color-surface-hover)]"
                              >
                                {/* Episode thumbnail */}
                                <div className="relative h-16 w-28 shrink-0 overflow-hidden rounded-md bg-[var(--color-bg)]">
                                  {ep.stillUrl ? (
                                    <Image
                                      src={ep.stillUrl}
                                      alt={ep.name}
                                      fill
                                      sizes="112px"
                                      className="object-cover"
                                    />
                                  ) : (
                                    <div className="flex h-full items-center justify-center text-xs text-[var(--color-text-muted)]">
                                      E{ep.episodeNumber}
                                    </div>
                                  )}
                                </div>

                                {/* Episode info */}
                                <div className="flex flex-1 flex-col gap-1 min-w-0">
                                  <div className="flex items-center gap-2">
                                    <span className="text-xs font-semibold text-[var(--color-primary)]">
                                      E{ep.episodeNumber}
                                    </span>
                                    <h4 className="text-sm font-medium text-[var(--color-text)] truncate">
                                      {ep.name}
                                    </h4>
                                  </div>
                                  {ep.overview && (
                                    <p className="text-xs text-[var(--color-text-muted)] line-clamp-2">
                                      {ep.overview}
                                    </p>
                                  )}
                                  <div className="flex items-center gap-3 text-xs text-[var(--color-text-muted)]">
                                    {ep.airDate && (
                                      <span>{formatDate(ep.airDate)}</span>
                                    )}
                                    {ep.runtime && <span>{ep.runtime}m</span>}
                                    {ep.rating > 0 && (
                                      <span className="text-yellow-400">
                                        {ep.rating.toFixed(1)}
                                      </span>
                                    )}
                                  </div>
                                </div>

                                {/* Play button */}
                                <button
                                  onClick={() => handleStreamEpisode(ep)}
                                  disabled={isStreamLoading}
                                  className="shrink-0 flex items-center gap-1.5 rounded-md bg-[var(--color-primary)] px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-[var(--color-primary-hover)] disabled:opacity-50"
                                >
                                  {isStreamLoading ? (
                                    <svg
                                      className="h-3.5 w-3.5 animate-spin"
                                      viewBox="0 0 24 24"
                                      fill="none"
                                    >
                                      <circle
                                        className="opacity-25"
                                        cx="12"
                                        cy="12"
                                        r="10"
                                        stroke="currentColor"
                                        strokeWidth="4"
                                      />
                                      <path
                                        className="opacity-75"
                                        fill="currentColor"
                                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                                      />
                                    </svg>
                                  ) : (
                                    <svg
                                      className="h-3.5 w-3.5 fill-white"
                                      viewBox="0 0 24 24"
                                    >
                                      <path d="M8 5v14l11-7z" />
                                    </svg>
                                  )}
                                  Play
                                </button>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })}

            {/* Specials season (if exists) */}
            {specialsSeason && (
              <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden">
                <button
                  onClick={() => toggleSeason(0)}
                  className="flex w-full items-center justify-between px-4 py-3 text-left transition-colors hover:bg-[var(--color-surface-hover)]"
                >
                  <div>
                    <h3 className="text-sm font-medium text-[var(--color-text)]">
                      Specials
                    </h3>
                    <p className="text-xs text-[var(--color-text-muted)]">
                      {specialsSeason.episodeCount} episode{specialsSeason.episodeCount !== 1 ? "s" : ""}
                    </p>
                  </div>
                  <svg
                    className={`h-5 w-5 text-[var(--color-text-muted)] transition-transform duration-200 ${
                      expandedSeason === 0 ? "rotate-180" : ""
                    }`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M19 9l-7 7-7-7"
                    />
                  </svg>
                </button>

                {expandedSeason === 0 && (
                  <div className="border-t border-[var(--color-border)]">
                    {seasonLoading === 0 ? (
                      <div className="flex flex-col gap-2 p-4">
                        {Array.from({ length: 3 }).map((_, i) => (
                          <Skeleton key={i} className="h-16 w-full rounded-md" />
                        ))}
                      </div>
                    ) : (seasonData[0]?.episodes || []).length === 0 ? (
                      <p className="p-4 text-sm text-[var(--color-text-muted)]">
                        No specials available
                      </p>
                    ) : (
                      <div className="divide-y divide-[var(--color-border)]">
                        {(seasonData[0]?.episodes || []).map((ep) => {
                          const epKey = `S0E${ep.episodeNumber}`;
                          const isStreamLoading = streamLoading === epKey;

                          return (
                            <div
                              key={ep.id}
                              className="flex items-center gap-3 p-3 transition-colors hover:bg-[var(--color-surface-hover)]"
                            >
                              <div className="flex flex-1 flex-col gap-0.5 min-w-0">
                                <h4 className="text-sm font-medium text-[var(--color-text)] truncate">
                                  {ep.name}
                                </h4>
                                {ep.airDate && (
                                  <span className="text-xs text-[var(--color-text-muted)]">
                                    {formatDate(ep.airDate)}
                                  </span>
                                )}
                              </div>
                              <button
                                onClick={() => handleStreamEpisode(ep)}
                                disabled={isStreamLoading}
                                className="shrink-0 flex items-center gap-1.5 rounded-md bg-[var(--color-primary)] px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-[var(--color-primary-hover)] disabled:opacity-50"
                              >
                                {isStreamLoading ? (
                                  <svg className="h-3.5 w-3.5 animate-spin" viewBox="0 0 24 24" fill="none">
                                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                                  </svg>
                                ) : (
                                  <svg className="h-3.5 w-3.5 fill-white" viewBox="0 0 24 24">
                                    <path d="M8 5v14l11-7z" />
                                  </svg>
                                )}
                                Play
                              </button>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        </section>

        {/* Similar TV Shows */}
        {show.similar.length > 0 && (
          <section>
            <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
              Similar Shows
            </h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
              {show.similar.map((s) => (
                <TvShowCard key={s.id} show={s} />
              ))}
            </div>
          </section>
        )}

        {/* Recommendations */}
        {show.recommendations.length > 0 && (
          <section>
            <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
              Recommended
            </h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
              {show.recommendations.map((s) => (
                <TvShowCard key={s.id} show={s} />
              ))}
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/movies-tv/tv/\[id\]/page.tsx
git commit -m "feat(web): add TV show detail page with seasons accordion and episode streaming"
```

---

### Task 8: Create News List Page

**Files:**
- Create: `web/app/(main)/news/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/news/page.tsx`**

```tsx
"use client";

import { useEffect, useState, useCallback } from "react";
import Image from "next/image";
import Link from "next/link";
import { newsService, type NewsItem } from "@/services/news.service";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate, truncate } from "@/lib/utils";

const CATEGORIES = [
  { value: "", label: "All" },
  { value: "anime", label: "Anime" },
  { value: "manga", label: "Manga" },
  { value: "industry", label: "Industry" },
  { value: "games", label: "Games" },
  { value: "events", label: "Events" },
  { value: "reviews", label: "Reviews" },
];

export default function NewsPage() {
  const [news, setNews] = useState<NewsItem[]>([]);
  const [trending, setTrending] = useState<NewsItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [trendingLoading, setTrendingLoading] = useState(true);

  const [activeCategory, setActiveCategory] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");

  // Debounce search
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(searchQuery), 400);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  // Fetch trending (one-time)
  useEffect(() => {
    let cancelled = false;
    setTrendingLoading(true);

    newsService
      .getTrending(5)
      .then((data) => {
        if (!cancelled) setTrending(data);
      })
      .catch((err) => {
        if (!cancelled) console.error("Failed to load trending news:", err);
      })
      .finally(() => {
        if (!cancelled) setTrendingLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  // Fetch news based on category/search
  const fetchNews = useCallback(async () => {
    setLoading(true);
    try {
      let result: NewsItem[];

      if (debouncedSearch.trim()) {
        result = await newsService.search(debouncedSearch, 20);
      } else if (activeCategory) {
        result = await newsService.getByCategory(activeCategory, 20);
      } else {
        result = await newsService.getRecent(20);
      }

      setNews(result);
    } catch (err) {
      console.error("Failed to load news:", err);
    } finally {
      setLoading(false);
    }
  }, [debouncedSearch, activeCategory]);

  useEffect(() => {
    fetchNews();
  }, [fetchNews]);

  return (
    <div className="flex flex-col lg:flex-row gap-6 p-4 sm:p-6">
      {/* Main Content */}
      <div className="flex-1 min-w-0">
        {/* Header */}
        <div className="flex flex-col gap-4 mb-6">
          <h1 className="text-2xl font-bold text-[var(--color-text)]">News</h1>

          {/* Search */}
          <div className="relative w-full sm:w-80">
            <input
              type="text"
              placeholder="Search news..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-2 pl-10 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] outline-none focus:border-[var(--color-primary)] transition-colors"
            />
            <svg
              className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-text-muted)]"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              />
            </svg>
          </div>

          {/* Category pills */}
          <div className="flex flex-wrap gap-2">
            {CATEGORIES.map((cat) => (
              <button
                key={cat.value}
                onClick={() => {
                  setActiveCategory(cat.value);
                  setSearchQuery("");
                }}
                className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
                  activeCategory === cat.value
                    ? "bg-[var(--color-primary)] text-white"
                    : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text)]"
                }`}
              >
                {cat.label}
              </button>
            ))}
          </div>
        </div>

        {/* News List */}
        {loading ? (
          <div className="flex flex-col gap-4">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="flex gap-4">
                <Skeleton className="h-24 w-36 shrink-0 rounded-lg" />
                <div className="flex flex-1 flex-col gap-2">
                  <Skeleton className="h-5 w-3/4" />
                  <Skeleton className="h-3 w-full" />
                  <Skeleton className="h-3 w-1/2" />
                </div>
              </div>
            ))}
          </div>
        ) : news.length === 0 ? (
          <p className="py-8 text-center text-[var(--color-text-muted)]">
            {debouncedSearch
              ? `No results found for "${debouncedSearch}"`
              : "No news articles available"}
          </p>
        ) : (
          <div className="flex flex-col gap-4">
            {news.map((article) => (
              <Link
                key={article.id}
                href={`/news/${article.id}`}
                className="group flex gap-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3 transition-colors hover:bg-[var(--color-surface-hover)]"
              >
                {/* Cover image */}
                <div className="relative h-24 w-36 shrink-0 overflow-hidden rounded-md bg-[var(--color-bg)]">
                  {article.coverImage ? (
                    <Image
                      src={article.coverImage}
                      alt={article.title}
                      fill
                      sizes="144px"
                      className="object-cover"
                    />
                  ) : (
                    <div className="flex h-full items-center justify-center text-2xl text-[var(--color-text-muted)]">
                      N
                    </div>
                  )}
                </div>

                {/* Text content */}
                <div className="flex flex-1 flex-col gap-1.5 min-w-0">
                  <h3 className="text-sm font-semibold text-[var(--color-text)] line-clamp-2 group-hover:text-[var(--color-primary)] transition-colors">
                    {article.title}
                  </h3>
                  <p className="text-xs text-[var(--color-text-muted)] line-clamp-2">
                    {article.excerpt}
                  </p>
                  <div className="flex items-center gap-2 mt-auto text-xs text-[var(--color-text-muted)]">
                    <span className="rounded bg-[var(--color-bg)] px-1.5 py-0.5 capitalize">
                      {article.category}
                    </span>
                    <span>{formatDate(article.publishedAt)}</span>
                    <span className="capitalize text-[var(--color-text-muted)]/70">
                      {article.source}
                    </span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>

      {/* Sidebar: Trending */}
      <aside className="w-full lg:w-72 shrink-0">
        <div className="sticky top-20 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <h2 className="mb-4 text-sm font-semibold text-[var(--color-text)] uppercase tracking-wider">
            Trending
          </h2>

          {trendingLoading ? (
            <div className="flex flex-col gap-3">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex flex-col gap-1">
                  <Skeleton className="h-4 w-full" />
                  <Skeleton className="h-3 w-2/3" />
                </div>
              ))}
            </div>
          ) : trending.length === 0 ? (
            <p className="text-xs text-[var(--color-text-muted)]">
              No trending news
            </p>
          ) : (
            <div className="flex flex-col gap-3">
              {trending.map((article, index) => (
                <Link
                  key={article.id}
                  href={`/news/${article.id}`}
                  className="group flex gap-2"
                >
                  <span className="text-lg font-bold text-[var(--color-primary)]/40 shrink-0 w-6">
                    {index + 1}
                  </span>
                  <div className="flex flex-col gap-0.5 min-w-0">
                    <h3 className="text-xs font-medium text-[var(--color-text)] line-clamp-2 group-hover:text-[var(--color-primary)] transition-colors">
                      {article.title}
                    </h3>
                    <span className="text-[10px] text-[var(--color-text-muted)]">
                      {formatDate(article.publishedAt)}
                    </span>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </div>
      </aside>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/news/page.tsx
git commit -m "feat(web): add news list page with categories, search, and trending sidebar"
```

---

### Task 9: Create News Detail Page

**Files:**
- Create: `web/app/(main)/news/[id]/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/news/[id]/page.tsx`**

```tsx
"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Image from "next/image";
import Link from "next/link";
import { newsService, type NewsItem } from "@/services/news.service";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate } from "@/lib/utils";

export default function NewsDetailPage() {
  const params = useParams();
  const id = params.id as string;

  const [article, setArticle] = useState<NewsItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;

    let cancelled = false;
    setLoading(true);
    setError(null);

    newsService
      .getById(id)
      .then((data) => {
        if (!cancelled) setArticle(data);
      })
      .catch((err) => {
        if (!cancelled) setError(err?.message || "Failed to load article");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [id]);

  if (loading) {
    return (
      <div className="mx-auto max-w-3xl p-4 sm:p-6">
        <Skeleton className="mb-4 h-8 w-3/4" />
        <Skeleton className="mb-2 h-4 w-1/3" />
        <Skeleton className="mb-6 h-[300px] w-full rounded-xl" />
        <Skeleton className="mb-2 h-4 w-full" />
        <Skeleton className="mb-2 h-4 w-full" />
        <Skeleton className="mb-2 h-4 w-2/3" />
      </div>
    );
  }

  if (error || !article) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 p-12">
        <p className="text-[var(--color-danger)] text-lg">
          {error || "Article not found"}
        </p>
        <Link
          href="/news"
          className="text-[var(--color-primary)] hover:underline"
        >
          Back to News
        </Link>
      </div>
    );
  }

  return (
    <article className="mx-auto max-w-3xl p-4 sm:p-6">
      {/* Back link */}
      <Link
        href="/news"
        className="mb-4 inline-flex items-center gap-1 text-sm text-[var(--color-text-muted)] hover:text-[var(--color-primary)] transition-colors"
      >
        <svg
          className="h-4 w-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M15 19l-7-7 7-7"
          />
        </svg>
        Back to News
      </Link>

      {/* Header */}
      <header className="mb-6">
        <div className="mb-3 flex flex-wrap items-center gap-2 text-xs">
          <span className="rounded bg-[var(--color-primary)]/10 px-2 py-0.5 font-medium text-[var(--color-primary)] capitalize">
            {article.category}
          </span>
          <span className="text-[var(--color-text-muted)]">
            {formatDate(article.publishedAt)}
          </span>
          <span className="text-[var(--color-text-muted)] capitalize">
            {article.source}
          </span>
        </div>

        <h1 className="text-2xl sm:text-3xl font-bold text-[var(--color-text)] leading-tight">
          {article.title}
        </h1>

        {article.excerpt && (
          <p className="mt-3 text-base text-[var(--color-text-muted)] leading-relaxed">
            {article.excerpt}
          </p>
        )}
      </header>

      {/* Cover Image */}
      {article.coverImage && (
        <div className="relative mb-6 aspect-video w-full overflow-hidden rounded-xl bg-[var(--color-surface)]">
          <Image
            src={article.coverImage}
            alt={article.title}
            fill
            priority
            sizes="(max-width: 768px) 100vw, 768px"
            className="object-cover"
          />
        </div>
      )}

      {/* Content */}
      <div className="prose prose-invert max-w-none text-sm leading-relaxed text-[var(--color-text-muted)]">
        {article.content.split("\n").map((paragraph, i) => {
          const trimmed = paragraph.trim();
          if (!trimmed) return null;
          return (
            <p key={i} className="mb-4">
              {trimmed}
            </p>
          );
        })}
      </div>

      {/* Tags */}
      {article.tags && article.tags.length > 0 && (
        <div className="mt-8 flex flex-wrap items-center gap-2">
          <span className="text-xs font-medium text-[var(--color-text-muted)]">
            Tags:
          </span>
          {article.tags.map((tag) => (
            <span
              key={tag}
              className="rounded-full bg-[var(--color-surface)] px-3 py-0.5 text-xs text-[var(--color-text-muted)]"
            >
              {tag}
            </span>
          ))}
        </div>
      )}

      {/* External link */}
      {article.externalUrl && (
        <div className="mt-6 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <p className="mb-2 text-xs text-[var(--color-text-muted)]">
            Read the original article:
          </p>
          <a
            href={article.externalUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm font-medium text-[var(--color-primary)] hover:underline"
          >
            {article.externalUrl}
          </a>
        </div>
      )}
    </article>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/news/\[id\]/page.tsx
git commit -m "feat(web): add news detail page with full article, tags, and external link"
```

---

### Task 10: Smoke Test

- [ ] **Step 1: Verify TypeScript compilation**

```bash
cd web && npx tsc --noEmit 2>&1 | head -50
```

If there are import errors (e.g., `@/components/ui/Skeleton` or `@/lib/utils` missing), these are expected to be provided by Phase 1. Confirm only that Phase 4 files have no internal type errors between themselves.

- [ ] **Step 2: Verify dev server starts without crash**

```bash
cd web && npm run dev &
sleep 5
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/movies-tv
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/news
kill %1
```

Expected: both return `200` (or `302` if auth middleware redirects -- that is acceptable and means the route file was found).

- [ ] **Step 3: Visual spot check**

Open the following pages in a browser with backend running on port 3005:
- `/movies-tv` -- should show Movies tab with trending + popular grids, TV tab switchable
- `/movies-tv/movie/550` -- Fight Club detail page (TMDB ID 550) with hero, cast, trailer, Watch button
- `/movies-tv/tv/1399` -- Game of Thrones detail page with seasons accordion, episode play buttons
- `/news` -- should show recent news list with category pills, trending sidebar
- `/news/<any-valid-id>` -- should render full article with back link

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(web): complete Phase 4 - movies/TV browse+detail and news pages"
```

---

## Summary

| Task | Files | Purpose |
|------|-------|---------|
| 1 | `services/movies-tv.service.ts` | TMDB proxy: search, trending, popular, details, seasons, stream URLs |
| 2 | `services/news.service.ts` | News API: list, recent, trending, category, search, detail |
| 3 | `components/movies/MovieCard.tsx`, `TvShowCard.tsx` | Poster cards with rating badge, year, hover effect |
| 4 | `components/movies/CastGrid.tsx` | Horizontal scrollable cast photos with name + character |
| 5 | `app/(main)/movies-tv/page.tsx` | Browse page with Movies/TV tabs, trending + popular grids, inline search |
| 6 | `app/(main)/movies-tv/movie/[id]/page.tsx` | Movie detail: backdrop hero, metadata, cast, trailer, Watch iframe |
| 7 | `app/(main)/movies-tv/tv/[id]/page.tsx` | TV detail: hero, seasons accordion, lazy-loaded episodes, per-episode stream |
| 8 | `app/(main)/news/page.tsx` | News list: category pills, search, trending sidebar |
| 9 | `app/(main)/news/[id]/page.tsx` | News article: cover image, content paragraphs, tags, external link |
| 10 | -- | TypeScript check, dev server verification, visual spot check |
