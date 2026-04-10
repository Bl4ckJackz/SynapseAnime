"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Image from "next/image";
import { useToast } from "@/components/ui/Toast";
import { useSource } from "@/contexts/SourceContext";
import { Skeleton } from "@/components/ui/Skeleton";
import { EpisodeList } from "@/components/anime/EpisodeList";
import { animeService } from "@/services/anime.service";
import { cn } from "@/lib/utils";
import type { Anime, Episode } from "@/types/anime";

const statusColors: Record<string, string> = {
  ongoing: "bg-green-600",
  completed: "bg-blue-600",
  upcoming: "bg-amber-600",
};

export default function AnimeDetailPage() {
  const params = useParams<{ id: string }>();
  const { toast } = useToast();
  const { activeSource, sources, switchSource } = useSource();

  const [anime, setAnime] = useState<Anime | null>(null);
  const [episodes, setEpisodes] = useState<Episode[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!params.id) return;

    setLoading(true);
    Promise.all([
      animeService.getAnimeById(params.id),
      animeService.getEpisodes(params.id),
    ])
      .then(([animeData, episodesData]) => {
        setAnime(animeData);
        setEpisodes(episodesData);
      })
      .catch((err) =>
        toast(err.message || "Failed to load anime details", "error"),
      )
      .finally(() => setLoading(false));
  }, [params.id, toast]);

  if (loading) {
    return (
      <div className="flex flex-col gap-6 p-4 md:p-6">
        <Skeleton className="h-[300px] w-full rounded-xl" />
        <Skeleton className="h-8 w-1/3" />
        <Skeleton className="h-4 w-2/3" />
        <Skeleton className="h-4 w-1/2" />
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-24 w-full rounded-lg" />
          ))}
        </div>
      </div>
    );
  }

  if (!anime) {
    return (
      <div className="flex h-64 items-center justify-center">
        <p className="text-[var(--color-text-muted)]">Anime not found.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-8">
      {/* Hero banner */}
      <div className="relative h-[300px] w-full overflow-hidden md:h-[400px]">
        {anime.bannerImage || anime.coverUrl ? (
          <Image
            src={anime.bannerImage || anime.coverUrl!}
            alt={anime.title}
            fill
            sizes="100vw"
            className="object-cover"
            priority
          />
        ) : (
          <div className="h-full w-full bg-gradient-to-br from-[var(--color-primary)] to-[var(--color-surface)]" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-[var(--color-bg)] via-[var(--color-bg)]/60 to-transparent" />

        <div className="absolute bottom-0 left-0 right-0 flex gap-6 p-4 md:p-6">
          {/* Cover image */}
          <div className="relative hidden h-48 w-32 shrink-0 overflow-hidden rounded-lg shadow-lg md:block">
            {anime.coverUrl ? (
              <Image
                src={anime.coverUrl}
                alt={anime.title}
                fill
                sizes="128px"
                className="object-cover"
              />
            ) : (
              <div className="flex h-full w-full items-center justify-center bg-[var(--color-surface)]">
                <span className="text-2xl font-bold text-[var(--color-text-muted)]">
                  {anime.title.charAt(0)}
                </span>
              </div>
            )}
          </div>

          {/* Metadata */}
          <div className="flex flex-col justify-end gap-2">
            <h1 className="text-2xl font-bold text-[var(--color-text)] md:text-3xl">
              {anime.title}
            </h1>
            {anime.titleJapanese && (
              <p className="text-sm text-[var(--color-text-muted)]">
                {anime.titleJapanese}
              </p>
            )}
            <div className="flex flex-wrap items-center gap-3 text-sm text-[var(--color-text-muted)]">
              {anime.rating > 0 && (
                <span className="font-semibold text-yellow-400">
                  {anime.rating.toFixed(1)}
                </span>
              )}
              {anime.releaseYear && <span>{anime.releaseYear}</span>}
              <span
                className={cn(
                  "rounded px-2 py-0.5 text-xs font-medium uppercase text-white",
                  statusColors[anime.status] ?? "bg-gray-600",
                )}
              >
                {anime.status}
              </span>
              {anime.totalEpisodes > 0 && (
                <span>{anime.totalEpisodes} episodes</span>
              )}
              {anime.type && <span>{anime.type}</span>}
            </div>
            {anime.genres.length > 0 && (
              <div className="flex flex-wrap gap-1.5">
                {anime.genres.map((genre) => (
                  <span
                    key={genre}
                    className="rounded bg-[var(--color-surface)] px-2 py-0.5 text-xs text-[var(--color-text-muted)]"
                  >
                    {genre}
                  </span>
                ))}
              </div>
            )}
            {anime.studios && anime.studios.length > 0 && (
              <p className="text-xs text-[var(--color-text-muted)]">
                Studios: {anime.studios.join(", ")}
              </p>
            )}
          </div>
        </div>
      </div>

      <div className="flex flex-col gap-8 px-4 pb-8 md:px-6">
        {/* Synopsis */}
        {(anime.description || anime.synopsis) && (
          <section>
            <h2 className="mb-2 text-lg font-semibold text-[var(--color-text)]">
              Synopsis
            </h2>
            <p className="leading-relaxed text-[var(--color-text-muted)]">
              {anime.description || anime.synopsis}
            </p>
          </section>
        )}

        {/* Source selector */}
        {sources.length > 1 && (
          <section>
            <h2 className="mb-2 text-lg font-semibold text-[var(--color-text)]">
              Source
            </h2>
            <select
              value={activeSource?.id ?? ""}
              onChange={(e) => switchSource(e.target.value)}
              className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2 text-sm text-[var(--color-text)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]"
            >
              {sources.map((source) => (
                <option key={source.id} value={source.id}>
                  {source.name}
                </option>
              ))}
            </select>
          </section>
        )}

        {/* Episodes */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
            Episodes
          </h2>
          <EpisodeList episodes={episodes} animeId={anime.id} />
        </section>
      </div>
    </div>
  );
}
