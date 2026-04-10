"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Image from "next/image";
import { moviesTvService } from "@/services/movies-tv.service";
import { MovieCard } from "@/components/movies/MovieCard";
import { CastGrid } from "@/components/movies/CastGrid";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate } from "@/lib/utils";
import type { Movie } from "@/types/movies-tv";

export default function MovieDetailPage() {
  const params = useParams();
  const id = Number(params.id);

  const [movie, setMovie] = useState<Movie | null>(null);
  const [loading, setLoading] = useState(true);
  const [streamUrl, setStreamUrl] = useState<string | null>(null);
  const [showPlayer, setShowPlayer] = useState(false);
  const [loadingStream, setLoadingStream] = useState(false);

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    moviesTvService
      .getMovieDetails(id)
      .then(setMovie)
      .catch((err) => console.error("Failed to load movie:", err))
      .finally(() => setLoading(false));
  }, [id]);

  const handleWatch = async () => {
    if (streamUrl) {
      setShowPlayer(true);
      return;
    }
    setLoadingStream(true);
    try {
      const result = await moviesTvService.getMovieStreamUrl(id);
      setStreamUrl(result.url);
      setShowPlayer(true);
    } catch (err) {
      console.error("Failed to get stream URL:", err);
    } finally {
      setLoadingStream(false);
    }
  };

  if (loading) {
    return (
      <div className="space-y-6 p-4 lg:p-8">
        <Skeleton className="h-[400px] w-full" />
        <Skeleton className="h-8 w-1/2" />
        <Skeleton className="h-4 w-full" />
        <Skeleton className="h-4 w-3/4" />
      </div>
    );
  }

  if (!movie) {
    return (
      <div className="flex h-96 items-center justify-center">
        <p className="text-[var(--color-text-muted)]">Movie not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Hero Section */}
      <div className="relative h-[50vh] min-h-[400px] w-full">
        {movie.backdropPath ? (
          <Image
            src={`https://image.tmdb.org/t/p/original${movie.backdropPath}`}
            alt={movie.title}
            fill
            className="object-cover"
            priority
          />
        ) : (
          <div className="h-full w-full bg-[var(--color-surface)]" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-[var(--color-bg)] via-[var(--color-bg)]/60 to-transparent" />

        <div className="absolute bottom-0 left-0 right-0 flex gap-6 p-4 lg:p-8">
          {/* Poster */}
          <div className="relative hidden h-64 w-44 flex-shrink-0 overflow-hidden rounded-lg shadow-lg sm:block">
            {movie.posterPath ? (
              <Image
                src={`https://image.tmdb.org/t/p/w500${movie.posterPath}`}
                alt={movie.title}
                fill
                className="object-cover"
              />
            ) : (
              <div className="flex h-full w-full items-center justify-center bg-[var(--color-surface-hover)] text-[var(--color-text-muted)]">
                No Poster
              </div>
            )}
          </div>

          {/* Info */}
          <div className="flex flex-col justify-end gap-2">
            <h1 className="text-2xl font-bold text-white lg:text-4xl">
              {movie.title}
            </h1>
            {movie.tagline && (
              <p className="text-sm italic text-gray-300">{movie.tagline}</p>
            )}
            <div className="flex flex-wrap items-center gap-3 text-sm text-gray-300">
              <span className="rounded bg-[var(--color-primary)] px-2 py-0.5 font-bold text-white">
                {movie.voteAverage.toFixed(1)}
              </span>
              {movie.runtime && <span>{movie.runtime} min</span>}
              {movie.releaseDate && <span>{formatDate(movie.releaseDate)}</span>}
            </div>
            {movie.genres.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {movie.genres.map((genre) => (
                  <span
                    key={genre}
                    className="rounded-full border border-[var(--color-border)] px-2.5 py-0.5 text-xs text-gray-300"
                  >
                    {genre}
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="mx-auto max-w-7xl space-y-8 p-4 lg:p-8">
        {/* Watch Button */}
        <Button size="lg" onClick={handleWatch} loading={loadingStream}>
          {showPlayer ? "Now Playing" : "Watch Now"}
        </Button>

        {/* Player */}
        {showPlayer && streamUrl && (
          <div className="relative aspect-video w-full overflow-hidden rounded-lg bg-black">
            <iframe
              src={streamUrl}
              className="h-full w-full"
              allowFullScreen
              allow="autoplay; fullscreen"
              title={`Watch ${movie.title}`}
            />
            <button
              onClick={() => setShowPlayer(false)}
              className="absolute right-3 top-3 rounded-full bg-black/70 px-3 py-1 text-sm text-white hover:bg-black"
            >
              Close
            </button>
          </div>
        )}

        {/* Overview */}
        {movie.overview && (
          <section>
            <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
              Overview
            </h2>
            <p className="leading-relaxed text-[var(--color-text-muted)]">
              {movie.overview}
            </p>
          </section>
        )}

        {/* Cast */}
        <CastGrid cast={movie.cast} />

        {/* Similar Movies */}
        {movie.similar && movie.similar.length > 0 && (
          <section>
            <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
              Similar Movies
            </h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
              {movie.similar.slice(0, 10).map((m) => (
                <MovieCard key={m.id} movie={m} />
              ))}
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
