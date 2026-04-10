"use client";

import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/utils";
import type { Manga } from "@/types/manga";

interface MangaCardProps {
  manga: Manga;
  className?: string;
}

export function MangaCard({ manga, className }: MangaCardProps) {
  const href = `/manga/${manga.id || manga.mangadexId}`;

  return (
    <Link
      href={href}
      className={cn(
        "group relative flex flex-col overflow-hidden rounded-xl bg-[var(--color-surface)] border border-[var(--color-border)] transition-all duration-300 hover:scale-[1.03] hover:shadow-xl hover:shadow-black/20",
        className,
      )}
    >
      {/* Cover image */}
      <div className="relative aspect-[3/4] w-full overflow-hidden">
        {manga.coverImage ? (
          <Image
            src={manga.coverImage}
            alt={manga.title}
            fill
            className="object-cover transition-transform duration-300 group-hover:scale-110"
            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 20vw"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-[var(--color-surface-hover)]">
            <span className="text-4xl text-[var(--color-text-muted)]">?</span>
          </div>
        )}

        {/* Rating badge */}
        {manga.rating > 0 && (
          <div className="absolute top-2 left-2 flex items-center gap-1 rounded-md bg-black/70 px-2 py-0.5 text-xs font-semibold text-yellow-400 backdrop-blur-sm">
            <svg
              className="h-3 w-3 fill-yellow-400"
              viewBox="0 0 20 20"
            >
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.286 3.957a1 1 0 00.95.69h4.162c.969 0 1.371 1.24.588 1.81l-3.37 2.448a1 1 0 00-.364 1.118l1.287 3.957c.3.921-.755 1.688-1.54 1.118l-3.37-2.448a1 1 0 00-1.176 0l-3.37 2.448c-.784.57-1.838-.197-1.539-1.118l1.287-3.957a1 1 0 00-.364-1.118L2.063 9.384c-.783-.57-.38-1.81.588-1.81h4.162a1 1 0 00.95-.69l1.286-3.957z" />
            </svg>
            {manga.rating.toFixed(1)}
          </div>
        )}

        {/* Status badge */}
        <div
          className={cn(
            "absolute top-2 right-2 rounded-md px-2 py-0.5 text-xs font-medium capitalize backdrop-blur-sm",
            manga.status === "ongoing"
              ? "bg-green-500/80 text-white"
              : manga.status === "completed"
                ? "bg-blue-500/80 text-white"
                : manga.status === "hiatus"
                  ? "bg-yellow-500/80 text-white"
                  : "bg-red-500/80 text-white",
          )}
        >
          {manga.status}
        </div>
      </div>

      {/* Info */}
      <div className="flex flex-1 flex-col gap-1 p-3">
        <h3 className="line-clamp-2 text-sm font-semibold text-[var(--color-text)] group-hover:text-[var(--color-primary)]">
          {manga.title}
        </h3>
        {manga.authors.length > 0 && (
          <p className="line-clamp-1 text-xs text-[var(--color-text-muted)]">
            {manga.authors.join(", ")}
          </p>
        )}
      </div>
    </Link>
  );
}
