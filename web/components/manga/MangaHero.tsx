"use client";

import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/Button";
import type { Manga } from "@/types/manga";

interface MangaHeroProps {
  manga: Manga;
  firstChapterId?: string;
}

export function MangaHero({ manga, firstChapterId }: MangaHeroProps) {
  const mangaId = manga.id || manga.mangadexId;

  return (
    <section className="relative w-full overflow-hidden rounded-2xl bg-[var(--color-surface)]">
      {/* Background blur */}
      {manga.coverImage && (
        <div className="absolute inset-0 z-0">
          <Image
            src={manga.coverImage}
            alt=""
            fill
            className="object-cover blur-2xl opacity-20 scale-110"
            sizes="100vw"
            priority
          />
          <div className="absolute inset-0 bg-gradient-to-r from-[var(--color-surface)] via-[var(--color-surface)]/80 to-transparent" />
        </div>
      )}

      <div className="relative z-10 flex flex-col gap-6 p-6 md:flex-row md:gap-8 md:p-8">
        {/* Cover */}
        <div className="flex-shrink-0">
          <div className="relative aspect-[3/4] w-48 overflow-hidden rounded-xl shadow-2xl md:w-56">
            {manga.coverImage ? (
              <Image
                src={manga.coverImage}
                alt={manga.title}
                fill
                className="object-cover"
                sizes="224px"
                priority
              />
            ) : (
              <div className="flex h-full w-full items-center justify-center bg-[var(--color-surface-hover)]">
                <span className="text-6xl text-[var(--color-text-muted)]">
                  ?
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Details */}
        <div className="flex flex-1 flex-col gap-4">
          <h1 className="text-2xl font-bold text-[var(--color-text)] md:text-3xl lg:text-4xl">
            {manga.title}
          </h1>

          {/* Authors & Artists */}
          <div className="flex flex-wrap gap-x-6 gap-y-1 text-sm text-[var(--color-text-muted)]">
            {manga.authors.length > 0 && (
              <span>
                <span className="font-medium text-[var(--color-text)]">
                  Author:
                </span>{" "}
                {manga.authors.join(", ")}
              </span>
            )}
            {manga.artists.length > 0 && (
              <span>
                <span className="font-medium text-[var(--color-text)]">
                  Artist:
                </span>{" "}
                {manga.artists.join(", ")}
              </span>
            )}
          </div>

          {/* Meta row */}
          <div className="flex flex-wrap items-center gap-3 text-sm">
            {/* Status */}
            <span
              className={cn(
                "rounded-md px-2.5 py-1 text-xs font-medium capitalize",
                manga.status === "ongoing"
                  ? "bg-green-500/20 text-green-400"
                  : manga.status === "completed"
                    ? "bg-blue-500/20 text-blue-400"
                    : manga.status === "hiatus"
                      ? "bg-yellow-500/20 text-yellow-400"
                      : "bg-red-500/20 text-red-400",
              )}
            >
              {manga.status}
            </span>

            {/* Year */}
            {manga.year && (
              <span className="text-[var(--color-text-muted)]">
                {manga.year}
              </span>
            )}

            {/* Rating */}
            {manga.rating > 0 && (
              <span className="flex items-center gap-1 text-yellow-400">
                <svg className="h-4 w-4 fill-yellow-400" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.286 3.957a1 1 0 00.95.69h4.162c.969 0 1.371 1.24.588 1.81l-3.37 2.448a1 1 0 00-.364 1.118l1.287 3.957c.3.921-.755 1.688-1.54 1.118l-3.37-2.448a1 1 0 00-1.176 0l-3.37 2.448c-.784.57-1.838-.197-1.539-1.118l1.287-3.957a1 1 0 00-.364-1.118L2.063 9.384c-.783-.57-.38-1.81.588-1.81h4.162a1 1 0 00.95-.69l1.286-3.957z" />
                </svg>
                {manga.rating.toFixed(1)}
              </span>
            )}
          </div>

          {/* Genres */}
          {manga.genres.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {manga.genres.map((genre) => (
                <span
                  key={genre}
                  className="rounded-full bg-[var(--color-primary)]/10 px-3 py-1 text-xs font-medium text-[var(--color-primary)]"
                >
                  {genre}
                </span>
              ))}
            </div>
          )}

          {/* Description */}
          {manga.description && (
            <p className="line-clamp-4 text-sm leading-relaxed text-[var(--color-text-muted)] md:line-clamp-6">
              {manga.description}
            </p>
          )}

          {/* CTA */}
          {firstChapterId && (
            <div className="mt-2">
              <Link href={`/manga/${mangaId}/read/${firstChapterId}`}>
                <Button size="lg">Read First Chapter</Button>
              </Link>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
