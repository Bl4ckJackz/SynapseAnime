"use client";

import { useEffect, useState, useCallback } from "react";
import { useToast } from "@/components/ui/Toast";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Skeleton";
import { AnimeCard } from "@/components/anime/AnimeCard";
import { animeService } from "@/services/anime.service";
import { cn } from "@/lib/utils";
import type { Anime } from "@/types/anime";

export default function AnimeBrowsePage() {
  const { toast } = useToast();

  const [animeList, setAnimeList] = useState<Anime[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [activeGenre, setActiveGenre] = useState<string | null>(null);
  const [genres, setGenres] = useState<string[]>([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  // Fetch genres on mount
  useEffect(() => {
    animeService.getGenres().then(setGenres).catch(() => {});
  }, []);

  const fetchAnime = useCallback(
    async (p: number, search?: string, genre?: string | null) => {
      setLoading(true);
      try {
        let result;
        if (search && search.trim().length > 0) {
          result = await animeService.searchAnime(search.trim(), p, 24);
        } else {
          result = await animeService.getAnimeList({
            page: p,
            limit: 24,
            genre: genre ?? undefined,
          });
        }
        setAnimeList(result.data);
        setTotalPages(result.totalPages);
        setPage(result.page);
      } catch (err: any) {
        toast(err.message || "Failed to load anime", "error");
      } finally {
        setLoading(false);
      }
    },
    [toast],
  );

  // Initial fetch and refetch on genre change
  useEffect(() => {
    fetchAnime(1, searchQuery, activeGenre);
  }, [activeGenre]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setActiveGenre(null);
    fetchAnime(1, searchQuery, null);
  };

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6">
      <h1 className="text-2xl font-bold text-[var(--color-text)]">
        Browse Anime
      </h1>

      {/* Search bar */}
      <form onSubmit={handleSearch} className="flex gap-2">
        <div className="flex-1">
          <Input
            placeholder="Search anime..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <Button type="submit">Search</Button>
      </form>

      {/* Genre filter pills */}
      {genres.length > 0 && (
        <div className="scrollbar-hide flex flex-wrap gap-2">
          <button
            onClick={() => {
              setActiveGenre(null);
              setSearchQuery("");
            }}
            className={cn(
              "rounded-full px-3 py-1 text-sm transition-colors",
              activeGenre === null
                ? "bg-[var(--color-primary)] text-white"
                : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]",
            )}
          >
            All
          </button>
          {genres.map((genre) => (
            <button
              key={genre}
              onClick={() => {
                setActiveGenre(genre);
                setSearchQuery("");
              }}
              className={cn(
                "rounded-full px-3 py-1 text-sm transition-colors",
                activeGenre === genre
                  ? "bg-[var(--color-primary)] text-white"
                  : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]",
              )}
            >
              {genre}
            </button>
          ))}
        </div>
      )}

      {/* Anime grid */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
        {loading
          ? Array.from({ length: 12 }).map((_, i) => (
              <div key={i}>
                <Skeleton className="aspect-[3/4] w-full rounded-lg" />
                <Skeleton className="mt-2 h-4 w-3/4" />
                <Skeleton className="mt-1 h-3 w-1/2" />
              </div>
            ))
          : animeList.map((anime) => (
              <AnimeCard
                key={anime.id}
                anime={anime}
                className="w-full"
              />
            ))}
      </div>

      {!loading && animeList.length === 0 && (
        <p className="py-12 text-center text-[var(--color-text-muted)]">
          No anime found. Try a different search or filter.
        </p>
      )}

      {/* Pagination */}
      {totalPages > 1 && !loading && (
        <div className="flex items-center justify-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            disabled={page <= 1}
            onClick={() => fetchAnime(page - 1, searchQuery, activeGenre)}
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
            onClick={() => fetchAnime(page + 1, searchQuery, activeGenre)}
          >
            Next
          </Button>
        </div>
      )}
    </div>
  );
}
