"use client";

import { useEffect, useState } from "react";
import { useToast } from "@/components/ui/Toast";
import { Skeleton } from "@/components/ui/Skeleton";
import { AnimeCard } from "@/components/anime/AnimeCard";
import { animeService } from "@/services/anime.service";
import { cn } from "@/lib/utils";
import type { Anime } from "@/types/anime";

const DAYS = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
] as const;

const DAY_LABELS: Record<string, string> = {
  monday: "Mon",
  tuesday: "Tue",
  wednesday: "Wed",
  thursday: "Thu",
  friday: "Fri",
  saturday: "Sat",
  sunday: "Sun",
};

function getTodayDay(): string {
  const dayIndex = new Date().getDay();
  // getDay() returns 0=Sunday, convert to our array
  const mapped = dayIndex === 0 ? 6 : dayIndex - 1;
  return DAYS[mapped];
}

export default function CalendarPage() {
  const { toast } = useToast();
  const [activeDay, setActiveDay] = useState(getTodayDay());
  const [animeList, setAnimeList] = useState<Anime[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    animeService
      .getSchedule(activeDay)
      .then(setAnimeList)
      .catch((err) =>
        toast(err.message || "Failed to load schedule", "error"),
      )
      .finally(() => setLoading(false));
  }, [activeDay, toast]);

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6">
      <h1 className="text-2xl font-bold text-[var(--color-text)]">
        Airing Schedule
      </h1>

      {/* Day tabs */}
      <div className="scrollbar-hide flex gap-2 overflow-x-auto">
        {DAYS.map((day) => (
          <button
            key={day}
            onClick={() => setActiveDay(day)}
            className={cn(
              "shrink-0 rounded-lg px-4 py-2 text-sm font-medium transition-colors",
              activeDay === day
                ? "bg-[var(--color-primary)] text-white"
                : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]",
            )}
          >
            <span className="hidden sm:inline capitalize">{day}</span>
            <span className="sm:hidden">{DAY_LABELS[day]}</span>
          </button>
        ))}
      </div>

      {/* Anime grid */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
        {loading
          ? Array.from({ length: 12 }).map((_, i) => (
              <div key={i}>
                <Skeleton className="aspect-[3/4] w-full rounded-lg" />
                <Skeleton className="mt-2 h-4 w-3/4" />
                <Skeleton className="mt-1 h-3 w-1/2" />
              </div>
            ))
          : animeList.map((anime) => (
              <AnimeCard key={anime.id} anime={anime} className="w-full" />
            ))}
      </div>

      {!loading && animeList.length === 0 && (
        <p className="py-12 text-center text-[var(--color-text-muted)]">
          No anime scheduled for this day.
        </p>
      )}
    </div>
  );
}
