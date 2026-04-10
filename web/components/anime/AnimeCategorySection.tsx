"use client";

import { cn } from "@/lib/utils";
import { Skeleton } from "@/components/ui/Skeleton";
import { AnimeCard } from "@/components/anime/AnimeCard";
import type { Anime } from "@/types/anime";

interface AnimeCategorySectionProps {
  title: string;
  animeList: Anime[];
  loading?: boolean;
}

export function AnimeCategorySection({
  title,
  animeList,
  loading,
}: AnimeCategorySectionProps) {
  return (
    <section className="flex flex-col gap-4">
      <h2 className="text-xl font-bold text-[var(--color-text)]">{title}</h2>

      <div className="scrollbar-hide flex gap-4 overflow-x-auto pb-2">
        {loading
          ? Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="w-[180px] shrink-0">
                <Skeleton className="aspect-[3/4] w-full rounded-lg" />
                <Skeleton className="mt-2 h-4 w-3/4" />
                <Skeleton className="mt-1 h-3 w-1/2" />
              </div>
            ))
          : animeList.map((anime) => (
              <AnimeCard key={anime.id} anime={anime} />
            ))}

        {!loading && animeList.length === 0 && (
          <p className="text-sm text-[var(--color-text-muted)]">
            No anime found in this category.
          </p>
        )}
      </div>
    </section>
  );
}
