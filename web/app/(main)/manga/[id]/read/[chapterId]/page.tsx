"use client";

import { useCallback, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { mangaService } from "@/services/manga.service";
import { MangaReader, type ReaderMode } from "@/components/manga/MangaReader";
import { ReaderControls } from "@/components/manga/ReaderControls";
import { Skeleton } from "@/components/ui/Skeleton";
import type { Chapter } from "@/types/manga";

const READER_MODE_KEY = "synapse-reader-mode";

function getStoredMode(): ReaderMode {
  if (typeof window === "undefined") return "vertical";
  const stored = localStorage.getItem(READER_MODE_KEY);
  if (stored === "vertical" || stored === "horizontal" || stored === "webtoon") {
    return stored;
  }
  return "vertical";
}

export default function ChapterReaderPage() {
  const params = useParams<{ id: string; chapterId: string }>();
  const router = useRouter();
  const mangaId = params.id;
  const chapterId = params.chapterId;

  const [pages, setPages] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [mode, setMode] = useState<ReaderMode>("vertical");
  const [currentPage, setCurrentPage] = useState(0);
  const [isMangadex, setIsMangadex] = useState(false);

  // Chapters for prev/next navigation
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [currentChapterIndex, setCurrentChapterIndex] = useState(-1);

  // Restore mode from localStorage on mount
  useEffect(() => {
    setMode(getStoredMode());
  }, []);

  // Persist mode changes
  const handleModeChange = useCallback((newMode: ReaderMode) => {
    setMode(newMode);
    localStorage.setItem(READER_MODE_KEY, newMode);
  }, []);

  // Fetch pages
  useEffect(() => {
    if (!mangaId || !chapterId) return;

    async function fetchPages() {
      setLoading(true);
      setError(null);
      setCurrentPage(0);

      try {
        // Try MangaDex first
        try {
          const result = await mangaService.getChapterPages(chapterId);
          setPages(result.images);
          setIsMangadex(true);
        } catch {
          // Fallback to MangaHook
          const result = await mangaService.getMangaHookChapter(
            mangaId,
            chapterId,
          );
          setPages(result.images);
          setIsMangadex(false);
        }
      } catch {
        setError("Failed to load chapter pages.");
        setPages([]);
      } finally {
        setLoading(false);
      }
    }

    fetchPages();
  }, [mangaId, chapterId]);

  // Fetch chapter list for prev/next navigation
  useEffect(() => {
    if (!mangaId) return;

    async function fetchChapters() {
      try {
        const chapterList = await mangaService.getChapters(mangaId, "en");
        const sorted = [...chapterList].sort((a, b) => a.number - b.number);
        setChapters(sorted);
        const idx = sorted.findIndex(
          (ch) => ch.id === chapterId || ch.mangadexChapterId === chapterId,
        );
        setCurrentChapterIndex(idx);
      } catch {
        // Navigation won't work but reading still works
      }
    }

    fetchChapters();
  }, [mangaId, chapterId]);

  const handlePrev = useCallback(() => {
    if (currentChapterIndex > 0) {
      const prev = chapters[currentChapterIndex - 1];
      const prevId = prev.id || prev.mangadexChapterId;
      router.push(`/manga/${mangaId}/read/${prevId}`);
    }
  }, [chapters, currentChapterIndex, mangaId, router]);

  const handleNext = useCallback(() => {
    if (currentChapterIndex < chapters.length - 1) {
      const next = chapters[currentChapterIndex + 1];
      const nextId = next.id || next.mangadexChapterId;
      router.push(`/manga/${mangaId}/read/${nextId}`);
    }
  }, [chapters, currentChapterIndex, mangaId, router]);

  const handleFullscreen = useCallback(() => {
    if (document.fullscreenElement) {
      document.exitFullscreen();
    } else {
      document.documentElement.requestFullscreen();
    }
  }, []);

  if (loading) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-black p-4">
        <Skeleton className="h-[70vh] w-full max-w-3xl rounded-xl" />
        <p className="text-sm text-white/50">Loading chapter...</p>
      </div>
    );
  }

  if (error || pages.length === 0) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-black p-4">
        <div className="text-center">
          <h2 className="text-xl font-semibold text-white">
            {error || "No pages found"}
          </h2>
          <p className="mt-2 text-sm text-white/50">
            This chapter could not be loaded. Please try another chapter.
          </p>
          <button
            onClick={() => router.push(`/manga/${mangaId}`)}
            className="mt-4 rounded-lg bg-[var(--color-primary)] px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-[var(--color-primary-hover)]"
          >
            Back to Manga
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="relative min-h-screen bg-black">
      {/* Header bar */}
      <div className="sticky top-0 z-40 flex items-center gap-3 bg-black/90 px-4 py-2 backdrop-blur-sm">
        <button
          onClick={() => router.push(`/manga/${mangaId}`)}
          className="rounded-lg p-2 text-white/60 transition-colors hover:bg-white/10 hover:text-white"
        >
          <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <span className="truncate text-sm font-medium text-white/80">
          Chapter {chapters[currentChapterIndex]?.number ?? chapterId}
        </span>
      </div>

      {/* Reader */}
      <MangaReader
        pages={pages}
        mode={mode}
        currentPage={currentPage}
        onPageChange={setCurrentPage}
        mangadexProxy={isMangadex}
      />

      {/* Controls */}
      <ReaderControls
        mode={mode}
        onModeChange={handleModeChange}
        currentPage={currentPage}
        totalPages={pages.length}
        onPageChange={setCurrentPage}
        onPrev={currentChapterIndex > 0 ? handlePrev : undefined}
        onNext={
          currentChapterIndex < chapters.length - 1 ? handleNext : undefined
        }
        onFullscreen={handleFullscreen}
      />
    </div>
  );
}
