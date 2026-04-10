"use client";

import Link from "next/link";
import Image from "next/image";
import { cn } from "@/lib/utils";
import { formatDuration } from "@/lib/utils";
import type { Episode } from "@/types/anime";

interface EpisodeListProps {
  episodes: Episode[];
  animeId: string;
}

export function EpisodeList({ episodes, animeId }: EpisodeListProps) {
  if (episodes.length === 0) {
    return (
      <p className="py-8 text-center text-[var(--color-text-muted)]">
        No episodes available yet.
      </p>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      {episodes.map((episode) => (
        <Link
          key={episode.id}
          href={`/anime/${animeId}/watch/${episode.id}`}
          className="group flex gap-3 rounded-lg bg-[var(--color-surface)] p-3 transition-colors hover:bg-[var(--color-surface-hover)]"
        >
          {/* Thumbnail */}
          <div className="relative aspect-video w-28 shrink-0 overflow-hidden rounded-md">
            {episode.thumbnail ? (
              <Image
                src={episode.thumbnail}
                alt={episode.title || `Episode ${episode.number}`}
                fill
                sizes="112px"
                className="object-cover"
              />
            ) : (
              <div className="flex h-full w-full items-center justify-center bg-[var(--color-surface-hover)]">
                <span className="text-lg font-bold text-[var(--color-text-muted)]">
                  {episode.number}
                </span>
              </div>
            )}
            {/* Play icon overlay */}
            <div className="absolute inset-0 flex items-center justify-center bg-black/0 transition-colors group-hover:bg-black/40">
              <svg
                className="h-8 w-8 text-white opacity-0 transition-opacity group-hover:opacity-100"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path d="M8 5v14l11-7z" />
              </svg>
            </div>
          </div>

          {/* Info */}
          <div className="flex flex-col justify-center gap-1 overflow-hidden">
            <span className="text-xs font-medium text-[var(--color-primary)]">
              Episode {episode.number}
            </span>
            <h4 className="line-clamp-1 text-sm font-medium text-[var(--color-text)]">
              {episode.title || `Episode ${episode.number}`}
            </h4>
            {episode.duration > 0 && (
              <span className="text-xs text-[var(--color-text-muted)]">
                {formatDuration(episode.duration)}
              </span>
            )}
          </div>
        </Link>
      ))}
    </div>
  );
}
