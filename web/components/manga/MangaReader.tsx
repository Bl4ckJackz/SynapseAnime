"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Image from "next/image";
import { cn } from "@/lib/utils";
import { Skeleton } from "@/components/ui/Skeleton";

export type ReaderMode = "vertical" | "horizontal" | "webtoon";

interface MangaReaderProps {
  pages: string[];
  mode: ReaderMode;
  currentPage: number;
  onPageChange: (page: number) => void;
  mangadexProxy?: boolean;
}

function resolvePageUrl(url: string, mangadexProxy?: boolean): string {
  if (mangadexProxy && url.startsWith("http")) {
    return `/mangadex/image-proxy?url=${encodeURIComponent(url)}`;
  }
  return url;
}

function PageImage({
  src,
  alt,
  mode,
  mangadexProxy,
}: {
  src: string;
  alt: string;
  mode: ReaderMode;
  mangadexProxy?: boolean;
}) {
  const [loaded, setLoaded] = useState(false);
  const resolvedUrl = resolvePageUrl(src, mangadexProxy);

  return (
    <div
      className={cn(
        "relative flex items-center justify-center",
        mode === "webtoon" ? "w-full max-w-3xl mx-auto" : "w-full",
      )}
    >
      {!loaded && (
        <Skeleton
          className={cn(
            "w-full",
            mode === "horizontal" ? "h-[80vh]" : "h-[600px]",
          )}
        />
      )}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={resolvedUrl}
        alt={alt}
        className={cn(
          "max-w-full transition-opacity duration-300",
          loaded ? "opacity-100" : "opacity-0 absolute",
          mode === "horizontal" && "max-h-[85vh] object-contain mx-auto",
          mode === "webtoon" && "w-full",
        )}
        onLoad={() => setLoaded(true)}
        loading={mode === "horizontal" ? "eager" : "lazy"}
      />
    </div>
  );
}

export function MangaReader({
  pages,
  mode,
  currentPage,
  onPageChange,
  mangadexProxy,
}: MangaReaderProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const totalPages = pages.length;

  const goToPage = useCallback(
    (page: number) => {
      const clamped = Math.max(0, Math.min(page, totalPages - 1));
      onPageChange(clamped);
    },
    [totalPages, onPageChange],
  );

  // Keyboard navigation
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (mode === "horizontal") {
        if (e.key === "ArrowRight") {
          e.preventDefault();
          goToPage(currentPage + 1);
        } else if (e.key === "ArrowLeft") {
          e.preventDefault();
          goToPage(currentPage - 1);
        }
      } else {
        if (e.key === "ArrowDown" || e.key === "ArrowRight") {
          containerRef.current?.scrollBy({ top: 300, behavior: "smooth" });
        } else if (e.key === "ArrowUp" || e.key === "ArrowLeft") {
          containerRef.current?.scrollBy({ top: -300, behavior: "smooth" });
        }
      }
    }

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [mode, currentPage, goToPage]);

  // Track current page in vertical/webtoon mode via scroll position
  useEffect(() => {
    if (mode === "horizontal") return;

    const container = containerRef.current;
    if (!container) return;

    function handleScroll() {
      if (!container) return;
      const children = container.children;
      const scrollTop = container.scrollTop;
      const containerHeight = container.clientHeight;
      const midpoint = scrollTop + containerHeight / 2;

      let closestIdx = 0;
      let closestDist = Infinity;

      for (let i = 0; i < children.length; i++) {
        const child = children[i] as HTMLElement;
        const childMid = child.offsetTop + child.offsetHeight / 2;
        const dist = Math.abs(midpoint - childMid);
        if (dist < closestDist) {
          closestDist = dist;
          closestIdx = i;
        }
      }

      if (closestIdx !== currentPage) {
        onPageChange(closestIdx);
      }
    }

    container.addEventListener("scroll", handleScroll, { passive: true });
    return () => container.removeEventListener("scroll", handleScroll);
  }, [mode, currentPage, onPageChange]);

  // Horizontal mode: touch swipe
  useEffect(() => {
    if (mode !== "horizontal") return;
    const container = containerRef.current;
    if (!container) return;

    let startX = 0;

    function onTouchStart(e: TouchEvent) {
      startX = e.touches[0].clientX;
    }

    function onTouchEnd(e: TouchEvent) {
      const diff = startX - e.changedTouches[0].clientX;
      if (Math.abs(diff) > 50) {
        if (diff > 0) goToPage(currentPage + 1);
        else goToPage(currentPage - 1);
      }
    }

    container.addEventListener("touchstart", onTouchStart, { passive: true });
    container.addEventListener("touchend", onTouchEnd, { passive: true });
    return () => {
      container.removeEventListener("touchstart", onTouchStart);
      container.removeEventListener("touchend", onTouchEnd);
    };
  }, [mode, currentPage, goToPage]);

  if (totalPages === 0) {
    return (
      <div className="flex h-[60vh] items-center justify-center text-[var(--color-text-muted)]">
        No pages available for this chapter.
      </div>
    );
  }

  // ── Horizontal mode: single page ──
  if (mode === "horizontal") {
    return (
      <div
        ref={containerRef}
        className="flex h-[85vh] items-center justify-center select-none"
      >
        <PageImage
          src={pages[currentPage]}
          alt={`Page ${currentPage + 1}`}
          mode={mode}
          mangadexProxy={mangadexProxy}
        />

        {/* Page indicator */}
        <div className="absolute bottom-20 left-1/2 -translate-x-1/2 rounded-full bg-black/60 px-4 py-1.5 text-xs font-medium text-white backdrop-blur-sm">
          Page {currentPage + 1} / {totalPages}
        </div>
      </div>
    );
  }

  // ── Vertical / Webtoon mode: scrollable stack ──
  return (
    <div
      ref={containerRef}
      className={cn(
        "h-[85vh] overflow-y-auto scroll-smooth",
        mode === "webtoon" ? "flex flex-col items-center" : "flex flex-col gap-1",
      )}
    >
      {pages.map((page, idx) => (
        <PageImage
          key={idx}
          src={page}
          alt={`Page ${idx + 1}`}
          mode={mode}
          mangadexProxy={mangadexProxy}
        />
      ))}

      {/* Page indicator */}
      <div className="sticky bottom-4 left-1/2 z-10 -translate-x-1/2 self-center rounded-full bg-black/60 px-4 py-1.5 text-xs font-medium text-white backdrop-blur-sm">
        Page {currentPage + 1} / {totalPages}
      </div>
    </div>
  );
}
