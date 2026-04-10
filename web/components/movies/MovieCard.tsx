"use client";

import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/utils";

interface MovieCardProps {
  movie: {
    id: number;
    title: string;
    posterPath?: string;
    voteAverage: number;
    releaseDate?: string;
  };
  className?: string;
}

export function MovieCard({ movie, className }: MovieCardProps) {
  const year = movie.releaseDate
    ? new Date(movie.releaseDate).getFullYear()
    : null;

  return (
    <Link
      href={`/movies-tv/movie/${movie.id}`}
      className={cn(
        "group relative flex flex-col overflow-hidden rounded-lg bg-[var(--color-surface)] transition-transform hover:scale-105",
        className,
      )}
    >
      <div className="relative aspect-[2/3] w-full overflow-hidden">
        {movie.posterPath ? (
          <Image
            src={`https://image.tmdb.org/t/p/w500${movie.posterPath}`}
            alt={movie.title}
            fill
            className="object-cover transition-opacity group-hover:opacity-80"
            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 20vw"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-[var(--color-surface-hover)] text-[var(--color-text-muted)]">
            No Image
          </div>
        )}

        {/* Hover overlay */}
        <div className="absolute inset-0 flex items-center justify-center bg-black/60 opacity-0 transition-opacity group-hover:opacity-100">
          <span className="text-sm font-medium text-white">View Details</span>
        </div>

        {/* Rating badge */}
        <div className="absolute left-2 top-2 rounded-md bg-[var(--color-primary)] px-1.5 py-0.5 text-xs font-bold text-white">
          {movie.voteAverage.toFixed(1)}
        </div>
      </div>

      <div className="flex flex-col gap-1 p-3">
        <h3 className="line-clamp-2 text-sm font-medium text-[var(--color-text)]">
          {movie.title}
        </h3>
        {year && (
          <span className="text-xs text-[var(--color-text-muted)]">{year}</span>
        )}
      </div>
    </Link>
  );
}
