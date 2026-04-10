"use client";

import { useCallback, useEffect, useState } from "react";
import { cn } from "@/lib/utils";
import { mangaService } from "@/services/manga.service";
import { MangaCard } from "@/components/manga/MangaCard";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { Skeleton } from "@/components/ui/Skeleton";
import type { Manga } from "@/types/manga";
import type { PaginatedResult } from "@/types/api";

type Source = "jikan" | "mangadex" | "mangahook";

const SOURCE_TABS: { value: Source; label: string }[] = [
  { value: "jikan", label: "Jikan (MAL)" },
  { value: "mangadex", label: "MangaDex" },
  { value: "mangahook", label: "MangaHook" },
];

export default function MangaBrowsePage() {
  const [source, setSource] = useState<Source>("jikan");
  const [query, setQuery] = useState("");
  const [genre, setGenre] = useState("");
  const [genres, setGenres] = useState<string[]>([]);
  const [manga, setManga] = useState<Manga[]>([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);

  // Category sections for homepage view
  const [topManga, setTopManga] = useState<Manga[]>([]);
  const [recentManga, setRecentManga] = useState<Manga[]>([]);
  const [showBrowse, setShowBrowse] = useState(false);

  // Load genres on mount
  useEffect(() => {
    mangaService.getMangaGenres().then(setGenres).catch(() => {});
  }, []);

  // Load category sections on mount
  useEffect(() => {
    async function loadSections() {
      try {
        const [top, recent] = await Promise.all([
          mangaService.getTopManga(1),
          mangaService.getMangaHookList(1, undefined, "newest"),
        ]);
        setTopManga(top.data.slice(0, 12));
        setRecentManga(recent.data.slice(0, 12));
      } catch {
        // Sections are optional
      }
    }
    loadSections();
  }, []);

  // Fetch manga based on source, query, page
  const fetchManga = useCallback(async () => {
    setLoading(true);
    try {
      let result: PaginatedResult<Manga> | { data: Manga[] };

      if (query.trim()) {
        switch (source) {
          case "jikan":
            result = await mangaService.searchJikan(query, page);
            break;
          case "mangadex":
            result = await mangaService.searchMangadex(query);
            break;
          case "mangahook":
            result = await mangaService.searchMangaHook(query, page);
            break;
        }
      } else {
        switch (source) {
          case "jikan":
            result = await mangaService.getTopManga(page);
            break;
          case "mangadex":
            result = await mangaService.searchMangadex("");
            break;
          case "mangahook":
            result = await mangaService.getMangaHookList(page);
            break;
        }
      }

      if ("totalPages" in result) {
        setManga(result.data);
        setTotalPages(result.totalPages);
      } else {
        setManga(result.data);
        setTotalPages(1);
      }
    } catch {
      setManga([]);
    } finally {
      setLoading(false);
    }
  }, [source, query, page]);

  useEffect(() => {
    if (showBrowse || query.trim()) {
      fetchManga();
    } else {
      setLoading(false);
    }
  }, [fetchManga, showBrowse, query]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    setShowBrowse(true);
  };

  const filteredManga = genre
    ? manga.filter((m) =>
        m.genres.some((g) => g.toLowerCase() === genre.toLowerCase()),
      )
    : manga;

  return (
    <div className="mx-auto max-w-7xl space-y-8 px-4 py-6">
      {/* Page header */}
      <div className="space-y-4">
        <h1 className="text-3xl font-bold text-[var(--color-text)]">
          Manga
        </h1>

        {/* Search bar */}
        <form onSubmit={handleSearch} className="flex gap-2">
          <div className="flex-1">
            <Input
              placeholder="Search manga..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
          </div>
          <Button type="submit">Search</Button>
        </form>

        {/* Source tabs */}
        <div className="flex gap-1 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-1">
          {SOURCE_TABS.map((tab) => (
            <button
              key={tab.value}
              onClick={() => {
                setSource(tab.value);
                setPage(1);
                if (showBrowse || query.trim()) setShowBrowse(true);
              }}
              className={cn(
                "flex-1 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                source === tab.value
                  ? "bg-[var(--color-primary)] text-white"
                  : "text-[var(--color-text-muted)] hover:text-[var(--color-text)]",
              )}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Genre filter */}
        {genres.length > 0 && (
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => setGenre("")}
              className={cn(
                "rounded-full px-3 py-1 text-xs font-medium transition-colors",
                !genre
                  ? "bg-[var(--color-primary)] text-white"
                  : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]",
              )}
            >
              All
            </button>
            {genres.map((g) => (
              <button
                key={g}
                onClick={() => {
                  setGenre(g);
                  setShowBrowse(true);
                }}
                className={cn(
                  "rounded-full px-3 py-1 text-xs font-medium transition-colors",
                  genre === g
                    ? "bg-[var(--color-primary)] text-white"
                    : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]",
                )}
              >
                {g}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Category sections (shown when not browsing) */}
      {!showBrowse && !query.trim() && (
        <div className="space-y-8">
          {/* Top Manga */}
          {topManga.length > 0 && (
            <section className="space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-semibold text-[var(--color-text)]">
                  Top Manga
                </h2>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    setSource("jikan");
                    setShowBrowse(true);
                  }}
                >
                  View All
                </Button>
              </div>
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6">
                {topManga.map((m) => (
                  <MangaCard key={m.id || m.mangadexId} manga={m} />
                ))}
              </div>
            </section>
          )}

          {/* Recently Updated */}
          {recentManga.length > 0 && (
            <section className="space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-semibold text-[var(--color-text)]">
                  Recently Updated
                </h2>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    setSource("mangahook");
                    setShowBrowse(true);
                  }}
                >
                  View All
                </Button>
              </div>
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6">
                {recentManga.map((m) => (
                  <MangaCard key={m.id || m.mangadexId} manga={m} />
                ))}
              </div>
            </section>
          )}
        </div>
      )}

      {/* Browse grid */}
      {(showBrowse || query.trim()) && (
        <div className="space-y-6">
          {loading ? (
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
              {Array.from({ length: 20 }).map((_, i) => (
                <div key={i} className="flex flex-col gap-2">
                  <Skeleton className="aspect-[3/4] w-full rounded-xl" />
                  <Skeleton className="h-4 w-3/4" />
                  <Skeleton className="h-3 w-1/2" />
                </div>
              ))}
            </div>
          ) : filteredManga.length === 0 ? (
            <div className="py-16 text-center text-[var(--color-text-muted)]">
              No manga found. Try a different search or source.
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
              {filteredManga.map((m) => (
                <MangaCard key={m.id || m.mangadexId} manga={m} />
              ))}
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-3">
              <Button
                variant="secondary"
                size="sm"
                disabled={page <= 1}
                onClick={() => setPage((p) => p - 1)}
              >
                Previous
              </Button>
              <span className="text-sm text-[var(--color-text-muted)]">
                Page {page} of {totalPages}
              </span>
              <Button
                variant="secondary"
                size="sm"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
