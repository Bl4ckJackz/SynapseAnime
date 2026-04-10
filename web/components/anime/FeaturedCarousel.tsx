"use client";

import { useState, useEffect, useCallback } from "react";
import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { truncate } from "@/lib/utils";
import { Button } from "@/components/ui/Button";
import type { Anime } from "@/types/anime";

interface FeaturedCarouselProps {
  animeList: Anime[];
}

export function FeaturedCarousel({ animeList }: FeaturedCarouselProps) {
  const [currentIndex, setCurrentIndex] = useState(0);

  const next = useCallback(() => {
    setCurrentIndex((prev) => (prev + 1) % animeList.length);
  }, [animeList.length]);

  const prev = useCallback(() => {
    setCurrentIndex(
      (prev) => (prev - 1 + animeList.length) % animeList.length,
    );
  }, [animeList.length]);

  useEffect(() => {
    if (animeList.length <= 1) return;
    const timer = setInterval(next, 6000);
    return () => clearInterval(timer);
  }, [next, animeList.length]);

  if (animeList.length === 0) return null;

  const anime = animeList[currentIndex];

  return (
    <div className="relative h-[400px] w-full overflow-hidden rounded-xl md:h-[500px]">
      {/* Backdrop image */}
      <div className="absolute inset-0">
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
        {/* Gradient overlay */}
        <div className="absolute inset-0 bg-gradient-to-r from-black/90 via-black/60 to-transparent" />
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent" />
      </div>

      {/* Content */}
      <div className="relative flex h-full flex-col justify-end p-6 md:max-w-2xl md:p-10">
        {/* Genres */}
        {anime.genres.length > 0 && (
          <div className="mb-3 flex flex-wrap gap-2">
            {anime.genres.slice(0, 4).map((genre) => (
              <span
                key={genre}
                className="rounded bg-white/20 px-2 py-0.5 text-xs font-medium text-white backdrop-blur-sm"
              >
                {genre}
              </span>
            ))}
          </div>
        )}

        <h2 className="mb-2 text-2xl font-bold text-white md:text-4xl">
          {anime.title}
        </h2>

        <div className="mb-3 flex items-center gap-3 text-sm text-white/70">
          {anime.rating > 0 && (
            <span className="font-semibold text-yellow-400">
              {anime.rating.toFixed(1)}
            </span>
          )}
          {anime.releaseYear && <span>{anime.releaseYear}</span>}
          {anime.totalEpisodes > 0 && (
            <span>{anime.totalEpisodes} eps</span>
          )}
          <span className="capitalize">{anime.status}</span>
        </div>

        {(anime.description || anime.synopsis) && (
          <p className="mb-4 text-sm leading-relaxed text-white/80 md:text-base">
            {truncate(anime.description || anime.synopsis || "", 200)}
          </p>
        )}

        <div className="flex gap-3">
          <Link href={`/anime/${anime.id}`}>
            <Button size="lg">Watch Now</Button>
          </Link>
        </div>
      </div>

      {/* Navigation arrows */}
      {animeList.length > 1 && (
        <>
          <button
            onClick={prev}
            className="absolute left-3 top-1/2 -translate-y-1/2 rounded-full bg-black/50 p-2 text-white transition-colors hover:bg-black/70"
            aria-label="Previous"
          >
            <svg
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </button>
          <button
            onClick={next}
            className="absolute right-3 top-1/2 -translate-y-1/2 rounded-full bg-black/50 p-2 text-white transition-colors hover:bg-black/70"
            aria-label="Next"
          >
            <svg
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <path d="M9 18l6-6-6-6" />
            </svg>
          </button>
        </>
      )}

      {/* Dots indicator */}
      {animeList.length > 1 && (
        <div className="absolute bottom-4 left-1/2 flex -translate-x-1/2 gap-2">
          {animeList.map((_, idx) => (
            <button
              key={idx}
              onClick={() => setCurrentIndex(idx)}
              className={cn(
                "h-2 rounded-full transition-all",
                idx === currentIndex
                  ? "w-6 bg-[var(--color-primary)]"
                  : "w-2 bg-white/40",
              )}
              aria-label={`Go to slide ${idx + 1}`}
            />
          ))}
        </div>
      )}
    </div>
  );
}
