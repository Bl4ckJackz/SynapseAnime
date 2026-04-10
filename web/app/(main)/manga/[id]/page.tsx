"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { mangaService } from "@/services/manga.service";
import { MangaHero } from "@/components/manga/MangaHero";
import { ChapterList } from "@/components/manga/ChapterList";
import { Skeleton } from "@/components/ui/Skeleton";
import type { Manga, Chapter } from "@/types/manga";

export default function MangaDetailPage() {
  const params = useParams<{ id: string }>();
  const mangaId = params.id;

  const [manga, setManga] = useState<Manga | null>(null);
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!mangaId) return;

    async function fetchData() {
      setLoading(true);
      setError(null);

      try {
        // Try MangaDex first
        let mangaData: Manga | null = null;
        let chapterData: Chapter[] = [];

        try {
          mangaData = await mangaService.getMangaDetails(mangaId);
          chapterData = await mangaService.getChapters(mangaId, "en");
        } catch {
          // Fallback to MangaHook
          try {
            mangaData = await mangaService.getMangaHookDetail(mangaId);
            // MangaHook chapters come from detail — no separate endpoint needed
          } catch {
            throw new Error("Could not load manga details from any source.");
          }
        }

        setManga(mangaData);
        setChapters(chapterData);
      } catch (err) {
        setError(
          err instanceof Error ? err.message : "Failed to load manga.",
        );
      } finally {
        setLoading(false);
      }
    }

    fetchData();
  }, [mangaId]);

  if (loading) {
    return (
      <div className="mx-auto max-w-7xl space-y-8 px-4 py-6">
        {/* Hero skeleton */}
        <div className="flex flex-col gap-6 rounded-2xl bg-[var(--color-surface)] p-6 md:flex-row md:p-8">
          <Skeleton className="aspect-[3/4] w-48 shrink-0 rounded-xl md:w-56" />
          <div className="flex flex-1 flex-col gap-4">
            <Skeleton className="h-10 w-3/4" />
            <Skeleton className="h-4 w-1/2" />
            <div className="flex gap-2">
              <Skeleton className="h-6 w-20 rounded-md" />
              <Skeleton className="h-6 w-16 rounded-md" />
              <Skeleton className="h-6 w-12 rounded-md" />
            </div>
            <div className="flex gap-2">
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-7 w-16 rounded-full" />
              ))}
            </div>
            <Skeleton className="h-20 w-full" />
          </div>
        </div>

        {/* Chapters skeleton */}
        <div className="space-y-3">
          <Skeleton className="h-6 w-40" />
          {Array.from({ length: 10 }).map((_, i) => (
            <Skeleton key={i} className="h-12 w-full rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  if (error || !manga) {
    return (
      <div className="flex min-h-[50vh] items-center justify-center px-4">
        <div className="text-center">
          <h2 className="text-xl font-semibold text-[var(--color-text)]">
            {error || "Manga not found"}
          </h2>
          <p className="mt-2 text-sm text-[var(--color-text-muted)]">
            The manga could not be loaded. Please try again later.
          </p>
        </div>
      </div>
    );
  }

  const firstChapterId =
    chapters.length > 0
      ? chapters.reduce((min, ch) => (ch.number < min.number ? ch : min), chapters[0])
      : null;

  return (
    <div className="mx-auto max-w-7xl space-y-8 px-4 py-6">
      <MangaHero
        manga={manga}
        firstChapterId={
          firstChapterId
            ? firstChapterId.id || firstChapterId.mangadexChapterId
            : undefined
        }
      />

      <ChapterList chapters={chapters} mangaId={mangaId} />
    </div>
  );
}
