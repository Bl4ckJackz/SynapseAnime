"use client";

import Link from "next/link";
import Image from "next/image";
import { cn } from "@/lib/utils";
import type { Anime } from "@/types/anime";

interface AnimeCardProps {
  anime: Anime;
  className?: string;
}

const statusColors: Record<string, string> = {
  ongoing: "bg-green-600",
  completed: "bg-blue-600",
  upcoming: "bg-amber-600",
};

export function AnimeCard({ anime, className }: AnimeCardProps) {
  return (
    <Link
      href={`/anime/${anime.id}`}
      className={cn(
        "group relative flex w-[180px] shrink-0 flex-col overflow-hidden rounded-lg bg-[var(--color-surface)] transition-transform duration-200 hover:scale-105",
        className,
      )}
    >
      <div className="relative aspect-[3/4] w-full overflow-hidden">
        {anime.coverUrl ? (
          <Image
            src={anime.coverUrl}
            alt={anime.title}
            fill
            sizes="180px"
            className="object-cover transition-opacity group-hover:opacity-80"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-[var(--color-primary)] to-[var(--color-surface)]">
            <span className="text-3xl font-bold text-white/40">
              {anime.title.charAt(0)}
            </span>
          </div>
        )}

        {/* Rating badge */}
        {anime.rating > 0 && (
          <div className="absolute left-2 top-2 rounded bg-black/70 px-1.5 py-0.5 text-xs font-semibold text-yellow-400">
            {anime.rating.toFixed(1)}
          </div>
        )}

        {/* Status badge */}
        <div
          className={cn(
            "absolute right-2 top-2 rounded px-1.5 py-0.5 text-[10px] font-medium uppercase text-white",
            statusColors[anime.status] ?? "bg-gray-600",
          )}
        >
          {anime.status}
        </div>
      </div>

      <div className="flex flex-col gap-1 p-2">
        <h3 className="line-clamp-2 text-sm font-medium leading-tight text-[var(--color-text)]">
          {anime.title}
        </h3>
        <p className="text-xs text-[var(--color-text-muted)]">
          {anime.totalEpisodes > 0
            ? `${anime.totalEpisodes} episodes`
            : "TBA"}
          {anime.releaseYear ? ` - ${anime.releaseYear}` : ""}
        </p>
      </div>
    </Link>
  );
}
