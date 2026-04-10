"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Image from "next/image";
import { moviesTvService } from "@/services/movies-tv.service";
import { TvShowCard } from "@/components/movies/TvShowCard";
import { CastGrid } from "@/components/movies/CastGrid";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate } from "@/lib/utils";
import type { TvShow, TvEpisode } from "@/types/movies-tv";

interface SeasonEpisodes {
  [seasonNumber: number]: {
    episodes: TvEpisode[];
    loading: boolean;
  };
}

export default function TvDetailPage() {
  const params = useParams();
  const id = Number(params.id);

  const [show, setShow] = useState<TvShow | null>(null);
  const [loading, setLoading] = useState(true);
  const [expandedSeason, setExpandedSeason] = useState<number | null>(null);
  const [seasonEpisodes, setSeasonEpisodes] = useState<SeasonEpisodes>({});
  const [streamUrl, setStreamUrl] = useState<string | null>(null);
  const [streamingEpisode, setStreamingEpisode] = useState<{
    season: number;
    episode: number;
  } | null>(null);

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    moviesTvService
      .getTvShowDetails(id)
      .then(setShow)
      .catch((err) => console.error("Failed to load TV show:", err))
      .finally(() => setLoading(false));
  }, [id]);

  const toggleSeason = async (seasonNumber: number) => {
    if (expandedSeason === seasonNumber) {
      setExpandedSeason(null);
      return;
    }

    setExpandedSeason(seasonNumber);

    if (seasonEpisodes[seasonNumber]) return;

    setSeasonEpisodes((prev) => ({
      ...prev,
      [seasonNumber]: { episodes: [], loading: true },
    }));

    try {
      const seasonDetail = await moviesTvService.getSeasonDetails(
        id,
        seasonNumber,
      );
      setSeasonEpisodes((prev) => ({
        ...prev,
        [seasonNumber]: { episodes: seasonDetail.episodes, loading: false },
      }));
    } catch (err) {
      console.error("Failed to load season:", err);
      setSeasonEpisodes((prev) => ({
        ...prev,
        [seasonNumber]: { episodes: [], loading: false },
      }));
    }
  };

  const handleWatchEpisode = async (season: number, episode: number) => {
    try {
      const result = await moviesTvService.getTvStreamUrl(id, season, episode);
      setStreamUrl(result.url);
      setStreamingEpisode({ season, episode });
    } catch (err) {
      console.error("Failed to get stream URL:", err);
    }
  };

  if (loading) {
    return (
      <div className="space-y-6 p-4 lg:p-8">
        <Skeleton className="h-[400px] w-full" />
        <Skeleton className="h-8 w-1/2" />
        <Skeleton className="h-4 w-full" />
      </div>
    );
  }

  if (!show) {
    return (
      <div className="flex h-96 items-center justify-center">
        <p className="text-[var(--color-text-muted)]">TV show not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Hero Section */}
      <div className="relative h-[50vh] min-h-[400px] w-full">
        {show.backdropPath ? (
          <Image
            src={`https://image.tmdb.org/t/p/original${show.backdropPath}`}
            alt={show.name}
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
            {show.posterPath ? (
              <Image
                src={`https://image.tmdb.org/t/p/w500${show.posterPath}`}
                alt={show.name}
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
              {show.name}
            </h1>
            <div className="flex flex-wrap items-center gap-3 text-sm text-gray-300">
              <span className="rounded bg-[var(--color-primary)] px-2 py-0.5 font-bold text-white">
                {show.voteAverage.toFixed(1)}
              </span>
              <span>{show.numberOfSeasons} Season{show.numberOfSeasons !== 1 ? "s" : ""}</span>
              <span>{show.numberOfEpisodes} Episodes</span>
              {show.firstAirDate && (
                <span>{formatDate(show.firstAirDate)}</span>
              )}
            </div>
            {show.genres.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {show.genres.map((genre) => (
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
        {/* Player */}
        {streamUrl && streamingEpisode && (
          <div className="relative aspect-video w-full overflow-hidden rounded-lg bg-black">
            <iframe
              src={streamUrl}
              className="h-full w-full"
              allowFullScreen
              allow="autoplay; fullscreen"
              title={`S${streamingEpisode.season}E${streamingEpisode.episode}`}
            />
            <button
              onClick={() => {
                setStreamUrl(null);
                setStreamingEpisode(null);
              }}
              className="absolute right-3 top-3 rounded-full bg-black/70 px-3 py-1 text-sm text-white hover:bg-black"
            >
              Close
            </button>
          </div>
        )}

        {/* Overview */}
        {show.overview && (
          <section>
            <h2 className="mb-3 text-lg font-semibold text-[var(--color-text)]">
              Overview
            </h2>
            <p className="leading-relaxed text-[var(--color-text-muted)]">
              {show.overview}
            </p>
          </section>
        )}

        {/* Cast */}
        <CastGrid cast={show.cast} />

        {/* Seasons Accordion */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
            Seasons
          </h2>
          <div className="space-y-2">
            {Array.from({ length: show.numberOfSeasons }, (_, i) => i + 1).map(
              (seasonNum) => (
                <div
                  key={seasonNum}
                  className="overflow-hidden rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]"
                >
                  <button
                    onClick={() => toggleSeason(seasonNum)}
                    className="flex w-full items-center justify-between px-4 py-3 text-left transition-colors hover:bg-[var(--color-surface-hover)]"
                  >
                    <span className="font-medium text-[var(--color-text)]">
                      Season {seasonNum}
                    </span>
                    <svg
                      className={`h-5 w-5 text-[var(--color-text-muted)] transition-transform ${
                        expandedSeason === seasonNum ? "rotate-180" : ""
                      }`}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M19 9l-7 7-7-7"
                      />
                    </svg>
                  </button>

                  {expandedSeason === seasonNum && (
                    <div className="border-t border-[var(--color-border)] px-4 py-3">
                      {seasonEpisodes[seasonNum]?.loading ? (
                        <div className="space-y-3">
                          {Array.from({ length: 3 }).map((_, i) => (
                            <Skeleton key={i} className="h-16 w-full" />
                          ))}
                        </div>
                      ) : seasonEpisodes[seasonNum]?.episodes.length === 0 ? (
                        <p className="text-sm text-[var(--color-text-muted)]">
                          No episodes available.
                        </p>
                      ) : (
                        <div className="space-y-2">
                          {seasonEpisodes[seasonNum]?.episodes.map((ep) => (
                            <div
                              key={ep.id}
                              className="flex items-center gap-4 rounded-lg p-3 transition-colors hover:bg-[var(--color-surface-hover)]"
                            >
                              {/* Episode thumbnail */}
                              <div className="relative hidden h-16 w-28 flex-shrink-0 overflow-hidden rounded bg-[var(--color-surface-hover)] sm:block">
                                {ep.stillPath ? (
                                  <Image
                                    src={`https://image.tmdb.org/t/p/w185${ep.stillPath}`}
                                    alt={ep.name}
                                    fill
                                    className="object-cover"
                                  />
                                ) : (
                                  <div className="flex h-full w-full items-center justify-center text-xs text-[var(--color-text-muted)]">
                                    Ep {ep.episodeNumber}
                                  </div>
                                )}
                              </div>

                              <div className="flex-1">
                                <p className="text-sm font-medium text-[var(--color-text)]">
                                  {ep.episodeNumber}. {ep.name}
                                </p>
                                {ep.overview && (
                                  <p className="mt-0.5 line-clamp-2 text-xs text-[var(--color-text-muted)]">
                                    {ep.overview}
                                  </p>
                                )}
                                <div className="mt-1 flex items-center gap-2 text-xs text-[var(--color-text-muted)]">
                                  {ep.airDate && (
                                    <span>{formatDate(ep.airDate)}</span>
                                  )}
                                  {ep.runtime && <span>{ep.runtime} min</span>}
                                </div>
                              </div>

                              <Button
                                size="sm"
                                onClick={() =>
                                  handleWatchEpisode(
                                    seasonNum,
                                    ep.episodeNumber,
                                  )
                                }
                              >
                                Watch
                              </Button>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              ),
            )}
          </div>
        </section>

        {/* Similar Shows */}
        {show.similar && show.similar.length > 0 && (
          <section>
            <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
              Similar TV Shows
            </h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
              {show.similar.slice(0, 10).map((s) => (
                <TvShowCard key={s.id} show={s} />
              ))}
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
