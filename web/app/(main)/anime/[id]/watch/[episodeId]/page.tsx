"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { useToast } from "@/components/ui/Toast";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Skeleton";
import { VideoPlayer } from "@/components/anime/VideoPlayer";
import { animeService } from "@/services/anime.service";
import { apiClient } from "@/services/api-client";
import type { Anime, Episode } from "@/types/anime";

interface WatchProgress {
  currentTime: number;
}

export default function WatchEpisodePage() {
  const params = useParams<{ id: string; episodeId: string }>();
  const { toast } = useToast();

  const [anime, setAnime] = useState<Anime | null>(null);
  const [episodes, setEpisodes] = useState<Episode[]>([]);
  const [loading, setLoading] = useState(true);
  const [initialTime, setInitialTime] = useState(0);

  const currentEpisode = useMemo(
    () => episodes.find((ep) => ep.id === params.episodeId),
    [episodes, params.episodeId],
  );

  const currentIndex = useMemo(
    () => episodes.findIndex((ep) => ep.id === params.episodeId),
    [episodes, params.episodeId],
  );

  const prevEpisode = currentIndex > 0 ? episodes[currentIndex - 1] : null;
  const nextEpisode =
    currentIndex >= 0 && currentIndex < episodes.length - 1
      ? episodes[currentIndex + 1]
      : null;

  // Fetch anime and episodes
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
        toast(err.message || "Failed to load episode data", "error"),
      )
      .finally(() => setLoading(false));
  }, [params.id, toast]);

  // Load saved progress
  useEffect(() => {
    if (!params.id || !params.episodeId) return;

    apiClient
      .get<WatchProgress>("/users/progress", {
        animeId: params.id,
        episodeId: params.episodeId,
      })
      .then((progress) => {
        if (progress?.currentTime) {
          setInitialTime(progress.currentTime);
        }
      })
      .catch(() => {
        // No saved progress, start from beginning
      });
  }, [params.id, params.episodeId]);

  // Save progress handler
  const handleProgress = useCallback(
    (seconds: number) => {
      if (!params.id || !params.episodeId) return;
      apiClient
        .post("/users/progress", {
          animeId: params.id,
          episodeId: params.episodeId,
          currentTime: seconds,
        })
        .catch(() => {
          // Silent fail for progress saving
        });
    },
    [params.id, params.episodeId],
  );

  if (loading) {
    return (
      <div className="flex flex-col gap-4 p-4 md:p-6">
        <Skeleton className="aspect-video w-full rounded-lg" />
        <Skeleton className="h-8 w-1/3" />
        <Skeleton className="h-4 w-1/2" />
      </div>
    );
  }

  if (!currentEpisode) {
    return (
      <div className="flex h-64 items-center justify-center">
        <p className="text-[var(--color-text-muted)]">Episode not found.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6">
      {/* Video player */}
      <VideoPlayer
        src={currentEpisode.streamUrl}
        onProgress={handleProgress}
        initialTime={initialTime}
      />

      {/* Episode info */}
      <div className="flex flex-col gap-2">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-xl font-bold text-[var(--color-text)]">
              {anime?.title}
            </h1>
            <p className="text-[var(--color-text-muted)]">
              Episode {currentEpisode.number}
              {currentEpisode.title
                ? ` - ${currentEpisode.title}`
                : ""}
            </p>
          </div>
        </div>
      </div>

      {/* Episode navigation */}
      <div className="flex items-center justify-between">
        {prevEpisode ? (
          <Link href={`/anime/${params.id}/watch/${prevEpisode.id}`}>
            <Button variant="secondary" size="sm">
              Previous Episode
            </Button>
          </Link>
        ) : (
          <div />
        )}

        <Link href={`/anime/${params.id}`}>
          <Button variant="ghost" size="sm">
            All Episodes
          </Button>
        </Link>

        {nextEpisode ? (
          <Link href={`/anime/${params.id}/watch/${nextEpisode.id}`}>
            <Button variant="secondary" size="sm">
              Next Episode
            </Button>
          </Link>
        ) : (
          <div />
        )}
      </div>
    </div>
  );
}
