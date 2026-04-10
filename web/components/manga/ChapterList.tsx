"use client";

import { useState, useMemo } from "react";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { formatDate } from "@/lib/utils";
import { Button } from "@/components/ui/Button";
import type { Chapter } from "@/types/manga";

interface ChapterListProps {
  chapters: Chapter[];
  mangaId: string;
}

const CHAPTERS_PER_PAGE = 50;

export function ChapterList({ chapters, mangaId }: ChapterListProps) {
  const [sortOrder, setSortOrder] = useState<"asc" | "desc">("desc");
  const [page, setPage] = useState(1);

  const sorted = useMemo(() => {
    const copy = [...chapters];
    copy.sort((a, b) =>
      sortOrder === "asc" ? a.number - b.number : b.number - a.number,
    );
    return copy;
  }, [chapters, sortOrder]);

  const totalPages = Math.ceil(sorted.length / CHAPTERS_PER_PAGE);
  const paginated = sorted.slice(
    (page - 1) * CHAPTERS_PER_PAGE,
    page * CHAPTERS_PER_PAGE,
  );

  return (
    <div className="flex flex-col gap-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-[var(--color-text)]">
          Chapters ({chapters.length})
        </h2>
        <button
          onClick={() => {
            setSortOrder((prev) => (prev === "asc" ? "desc" : "asc"));
            setPage(1);
          }}
          className="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm text-[var(--color-text-muted)] transition-colors hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text)]"
        >
          {sortOrder === "desc" ? (
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
            </svg>
          ) : (
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M5 15l7-7 7 7" />
            </svg>
          )}
          {sortOrder === "desc" ? "Newest first" : "Oldest first"}
        </button>
      </div>

      {/* Chapter list */}
      <div className="flex flex-col divide-y divide-[var(--color-border)] rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)]">
        {paginated.length === 0 && (
          <div className="px-4 py-8 text-center text-sm text-[var(--color-text-muted)]">
            No chapters available.
          </div>
        )}
        {paginated.map((chapter) => {
          const chapterId = chapter.id || chapter.mangadexChapterId;
          return (
            <Link
              key={chapterId}
              href={`/manga/${mangaId}/read/${chapterId}`}
              className="flex items-center gap-4 px-4 py-3 transition-colors hover:bg-[var(--color-surface-hover)]"
            >
              <span className="min-w-[3.5rem] text-sm font-medium text-[var(--color-primary)]">
                Ch. {chapter.number}
              </span>
              <span className="flex-1 truncate text-sm text-[var(--color-text)]">
                {chapter.title || `Chapter ${chapter.number}`}
              </span>
              {chapter.scanlationGroup && (
                <span className="hidden text-xs text-[var(--color-text-muted)] sm:inline">
                  {chapter.scanlationGroup}
                </span>
              )}
              <span className="text-xs text-[var(--color-text-muted)] whitespace-nowrap">
                {formatDate(chapter.publishedAt)}
              </span>
            </Link>
          );
        })}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            disabled={page <= 1}
            onClick={() => setPage((p) => p - 1)}
          >
            Previous
          </Button>
          <span className="text-sm text-[var(--color-text-muted)]">
            Page {page} of {totalPages}
          </span>
          <Button
            variant="secondary"
            size="sm"
            disabled={page >= totalPages}
            onClick={() => setPage((p) => p + 1)}
          >
            Next
          </Button>
        </div>
      )}
    </div>
  );
}
