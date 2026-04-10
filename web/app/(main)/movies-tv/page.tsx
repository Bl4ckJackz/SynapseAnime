"use client";

import { useEffect, useState, useCallback } from "react";
import { moviesTvService } from "@/services/movies-tv.service";
import { MovieCard } from "@/components/movies/MovieCard";
import { TvShowCard } from "@/components/movies/TvShowCard";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Skeleton";
import type { Movie, TvShow } from "@/types/movies-tv";

type Tab = "movies" | "tv";

export default function MoviesTvPage() {
  const [tab, setTab] = useState<Tab>("movies");
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<(Movie | TvShow)[]>([]);
  const [isSearching, setIsSearching] = useState(false);

  // Movies state
  const [trendingMovies, setTrendingMovies] = useState<Movie[]>([]);
  const [popularMovies, setPopularMovies] = useState<Movie[]>([]);
  const [moviesPage, setMoviesPage] = useState(1);
  const [moviesTotalPages, setMoviesTotalPages] = useState(1);
  const [loadingMovies, setLoadingMovies] = useState(true);

  // TV state
  const [trendingTv, setTrendingTv] = useState<TvShow[]>([]);
  const [popularTv, setPopularTv] = useState<TvShow[]>([]);
  const [tvPage, setTvPage] = useState(1);
  const [tvTotalPages, setTvTotalPages] = useState(1);
  const [loadingTv, setLoadingTv] = useState(true);

  const loadMovies = useCallback(async (page: number) => {
    setLoadingMovies(true);
    try {
      const [trending, popular] = await Promise.all([
        moviesTvService.getTrendingMovies(1),
        moviesTvService.getPopularMovies(page),
      ]);
      setTrendingMovies(trending.data);
      setPopularMovies(popular.data);
      setMoviesTotalPages(popular.totalPages);
    } catch (err) {
      console.error("Failed to load movies:", err);
    } finally {
      setLoadingMovies(false);
    }
  }, []);

  const loadTvShows = useCallback(async (page: number) => {
    setLoadingTv(true);
    try {
      const [trending, popular] = await Promise.all([
        moviesTvService.getTrendingTvShows(1),
        moviesTvService.getPopularTvShows(page),
      ]);
      setTrendingTv(trending.data);
      setPopularTv(popular.data);
      setTvTotalPages(popular.totalPages);
    } catch (err) {
      console.error("Failed to load TV shows:", err);
    } finally {
      setLoadingTv(false);
    }
  }, []);

  useEffect(() => {
    if (tab === "movies") {
      loadMovies(moviesPage);
    } else {
      loadTvShows(tvPage);
    }
  }, [tab, moviesPage, tvPage, loadMovies, loadTvShows]);

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      setSearchResults([]);
      setIsSearching(false);
      return;
    }
    setIsSearching(true);
    try {
      const results = await moviesTvService.searchMoviesTv(
        searchQuery,
        tab === "movies" ? "movie" : "tv",
      );
      setSearchResults(results.data as unknown as (Movie | TvShow)[]);
    } catch (err) {
      console.error("Search failed:", err);
    }
  };

  const clearSearch = () => {
    setSearchQuery("");
    setSearchResults([]);
    setIsSearching(false);
  };

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-4 lg:p-8">
      {/* Search */}
      <div className="flex gap-3">
        <div className="flex-1">
          <Input
            placeholder={`Search ${tab === "movies" ? "movies" : "TV shows"}...`}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSearch()}
          />
        </div>
        <Button onClick={handleSearch}>Search</Button>
        {isSearching && (
          <Button variant="ghost" onClick={clearSearch}>
            Clear
          </Button>
        )}
      </div>

      {/* Tabs */}
      <div className="flex gap-1 rounded-lg bg-[var(--color-surface)] p-1">
        <button
          onClick={() => { setTab("movies"); clearSearch(); }}
          className={`flex-1 rounded-md px-4 py-2 text-sm font-medium transition-colors ${
            tab === "movies"
              ? "bg-[var(--color-primary)] text-white"
              : "text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
          }`}
        >
          Movies
        </button>
        <button
          onClick={() => { setTab("tv"); clearSearch(); }}
          className={`flex-1 rounded-md px-4 py-2 text-sm font-medium transition-colors ${
            tab === "tv"
              ? "bg-[var(--color-primary)] text-white"
              : "text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
          }`}
        >
          TV Shows
        </button>
      </div>

      {/* Search Results */}
      {isSearching && (
        <section>
          <h2 className="mb-4 text-xl font-bold text-[var(--color-text)]">
            Search Results
          </h2>
          {searchResults.length === 0 ? (
            <p className="text-[var(--color-text-muted)]">No results found.</p>
          ) : (
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
              {searchResults.map((item) =>
                tab === "movies" ? (
                  <MovieCard key={item.id} movie={item as Movie} />
                ) : (
                  <TvShowCard key={item.id} show={item as TvShow} />
                ),
              )}
            </div>
          )}
        </section>
      )}

      {/* Content */}
      {!isSearching && tab === "movies" && (
        <>
          {/* Trending Movies */}
          <section>
            <h2 className="mb-4 text-xl font-bold text-[var(--color-text)]">
              Trending Movies
            </h2>
            {loadingMovies ? (
              <div className="flex gap-4 overflow-hidden">
                {Array.from({ length: 6 }).map((_, i) => (
                  <Skeleton key={i} className="h-72 w-44 flex-shrink-0" />
                ))}
              </div>
            ) : (
              <div className="flex gap-4 overflow-x-auto pb-4 scrollbar-thin scrollbar-track-transparent scrollbar-thumb-[var(--color-border)]">
                {trendingMovies.map((movie) => (
                  <MovieCard
                    key={movie.id}
                    movie={movie}
                    className="w-44 flex-shrink-0"
                  />
                ))}
              </div>
            )}
          </section>

          {/* Popular Movies Grid */}
          <section>
            <h2 className="mb-4 text-xl font-bold text-[var(--color-text)]">
              Popular Movies
            </h2>
            {loadingMovies ? (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
                {Array.from({ length: 10 }).map((_, i) => (
                  <Skeleton key={i} className="aspect-[2/3] w-full" />
                ))}
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
                {popularMovies.map((movie) => (
                  <MovieCard key={movie.id} movie={movie} />
                ))}
              </div>
            )}

            {/* Pagination */}
            <div className="mt-6 flex items-center justify-center gap-3">
              <Button
                variant="secondary"
                size="sm"
                disabled={moviesPage <= 1}
                onClick={() => setMoviesPage((p) => p - 1)}
              >
                Previous
              </Button>
              <span className="text-sm text-[var(--color-text-muted)]">
                Page {moviesPage} of {moviesTotalPages}
              </span>
              <Button
                variant="secondary"
                size="sm"
                disabled={moviesPage >= moviesTotalPages}
                onClick={() => setMoviesPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          </section>
        </>
      )}

      {!isSearching && tab === "tv" && (
        <>
          {/* Trending TV */}
          <section>
            <h2 className="mb-4 text-xl font-bold text-[var(--color-text)]">
              Trending TV Shows
            </h2>
            {loadingTv ? (
              <div className="flex gap-4 overflow-hidden">
                {Array.from({ length: 6 }).map((_, i) => (
                  <Skeleton key={i} className="h-72 w-44 flex-shrink-0" />
                ))}
              </div>
            ) : (
              <div className="flex gap-4 overflow-x-auto pb-4 scrollbar-thin scrollbar-track-transparent scrollbar-thumb-[var(--color-border)]">
                {trendingTv.map((show) => (
                  <TvShowCard
                    key={show.id}
                    show={show}
                    className="w-44 flex-shrink-0"
                  />
                ))}
              </div>
            )}
          </section>

          {/* Popular TV Grid */}
          <section>
            <h2 className="mb-4 text-xl font-bold text-[var(--color-text)]">
              Popular TV Shows
            </h2>
            {loadingTv ? (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
                {Array.from({ length: 10 }).map((_, i) => (
                  <Skeleton key={i} className="aspect-[2/3] w-full" />
                ))}
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
                {popularTv.map((show) => (
                  <TvShowCard key={show.id} show={show} />
                ))}
              </div>
            )}

            {/* Pagination */}
            <div className="mt-6 flex items-center justify-center gap-3">
              <Button
                variant="secondary"
                size="sm"
                disabled={tvPage <= 1}
                onClick={() => setTvPage((p) => p - 1)}
              >
                Previous
              </Button>
              <span className="text-sm text-[var(--color-text-muted)]">
                Page {tvPage} of {tvTotalPages}
              </span>
              <Button
                variant="secondary"
                size="sm"
                disabled={tvPage >= tvTotalPages}
                onClick={() => setTvPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
