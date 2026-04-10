"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/Button";
import type { ReaderMode } from "@/components/manga/MangaReader";

interface ReaderControlsProps {
  mode: ReaderMode;
  onModeChange: (mode: ReaderMode) => void;
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  onPrev?: () => void;
  onNext?: () => void;
  onFullscreen?: () => void;
}

const MODE_OPTIONS: { value: ReaderMode; label: string; icon: string }[] = [
  { value: "vertical", label: "Vertical", icon: "V" },
  { value: "horizontal", label: "Horizontal", icon: "H" },
  { value: "webtoon", label: "Webtoon", icon: "W" },
];

export function ReaderControls({
  mode,
  onModeChange,
  currentPage,
  totalPages,
  onPageChange,
  onPrev,
  onNext,
  onFullscreen,
}: ReaderControlsProps) {
  const [visible, setVisible] = useState(true);
  const hideTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const resetHideTimer = useCallback(() => {
    setVisible(true);
    if (hideTimerRef.current) clearTimeout(hideTimerRef.current);
    hideTimerRef.current = setTimeout(() => setVisible(false), 3000);
  }, []);

  // Auto-hide after 3 seconds
  useEffect(() => {
    resetHideTimer();
    return () => {
      if (hideTimerRef.current) clearTimeout(hideTimerRef.current);
    };
  }, [resetHideTimer]);

  // Show on mouse move / touch
  useEffect(() => {
    function handleInteraction() {
      resetHideTimer();
    }

    window.addEventListener("mousemove", handleInteraction);
    window.addEventListener("touchstart", handleInteraction);
    return () => {
      window.removeEventListener("mousemove", handleInteraction);
      window.removeEventListener("touchstart", handleInteraction);
    };
  }, [resetHideTimer]);

  return (
    <div
      className={cn(
        "fixed bottom-0 left-0 right-0 z-50 transition-all duration-300",
        visible
          ? "translate-y-0 opacity-100"
          : "translate-y-full opacity-0 pointer-events-none",
      )}
      onMouseEnter={() => {
        setVisible(true);
        if (hideTimerRef.current) clearTimeout(hideTimerRef.current);
      }}
      onMouseLeave={resetHideTimer}
    >
      <div className="mx-auto max-w-4xl px-4 pb-4">
        <div className="flex flex-wrap items-center gap-3 rounded-xl border border-white/10 bg-black/80 px-4 py-3 shadow-2xl backdrop-blur-md">
          {/* Prev chapter */}
          {onPrev && (
            <Button variant="ghost" size="sm" onClick={onPrev} className="text-white hover:bg-white/10">
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
              </svg>
              <span className="ml-1 hidden sm:inline">Prev Ch</span>
            </Button>
          )}

          {/* Page slider */}
          <div className="flex flex-1 items-center gap-3">
            <span className="min-w-[3rem] text-center text-xs font-medium text-white/70">
              {currentPage + 1}/{totalPages}
            </span>
            <input
              type="range"
              min={0}
              max={Math.max(totalPages - 1, 0)}
              value={currentPage}
              onChange={(e) => onPageChange(Number(e.target.value))}
              className="h-1.5 flex-1 cursor-pointer appearance-none rounded-full bg-white/20 accent-[var(--color-primary)] [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-[var(--color-primary)]"
            />
          </div>

          {/* Next chapter */}
          {onNext && (
            <Button variant="ghost" size="sm" onClick={onNext} className="text-white hover:bg-white/10">
              <span className="mr-1 hidden sm:inline">Next Ch</span>
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
              </svg>
            </Button>
          )}

          {/* Separator */}
          <div className="h-6 w-px bg-white/20" />

          {/* Mode selector */}
          <div className="flex items-center gap-1">
            {MODE_OPTIONS.map((opt) => (
              <button
                key={opt.value}
                onClick={() => onModeChange(opt.value)}
                title={opt.label}
                className={cn(
                  "h-8 w-8 rounded-lg text-xs font-bold transition-colors",
                  mode === opt.value
                    ? "bg-[var(--color-primary)] text-white"
                    : "text-white/60 hover:bg-white/10 hover:text-white",
                )}
              >
                {opt.icon}
              </button>
            ))}
          </div>

          {/* Fullscreen */}
          {onFullscreen && (
            <button
              onClick={onFullscreen}
              className="rounded-lg p-2 text-white/60 transition-colors hover:bg-white/10 hover:text-white"
              title="Toggle fullscreen"
            >
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5v-4m0 4h-4m4 0l-5-5" />
              </svg>
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
