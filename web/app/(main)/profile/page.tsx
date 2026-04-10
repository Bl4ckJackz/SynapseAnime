"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { userService, type WatchlistItem, type WatchHistory } from "@/services/user.service";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate, formatDuration } from "@/lib/utils";
import Link from "next/link";

type Tab = "watchlist" | "history" | "continue";

export default function ProfilePage() {
  const { user } = useAuth();
  const [tab, setTab] = useState<Tab>("watchlist");
  const [watchlist, setWatchlist] = useState<WatchlistItem[]>([]);
  const [history, setHistory] = useState<WatchHistory[]>([]);
  const [continueWatching, setContinueWatching] = useState<WatchHistory[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    try {
      const [wl, hist, cw] = await Promise.all([
        userService.getWatchlist(),
        userService.getHistory(20),
        userService.getContinueWatching(10),
      ]);
      setWatchlist(wl);
      setHistory(hist);
      setContinueWatching(cw);
    } catch {
      // handle error
    } finally {
      setLoading(false);
    }
  }

  const tabs: { key: Tab; label: string }[] = [
    { key: "watchlist", label: "Watchlist" },
    { key: "history", label: "History" },
    { key: "continue", label: "Continue Watching" },
  ];

  return (
    <div className="p-6">
      {/* Profile Header */}
      <div className="mb-8 flex items-center gap-4">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-[var(--color-primary)] text-2xl font-bold text-white">
          {user?.nickname?.[0]?.toUpperCase() || user?.email?.[0]?.toUpperCase() || "U"}
        </div>
        <div>
          <h1 className="text-2xl font-bold text-[var(--color-text)]">
            {user?.nickname || "User"}
          </h1>
          <p className="text-sm text-[var(--color-text-muted)]">{user?.email}</p>
          <p className="text-xs text-[var(--color-text-muted)]">
            Joined {user?.createdAt ? formatDate(user.createdAt) : ""}
          </p>
        </div>
        <Link href="/settings" className="ml-auto">
          <Button variant="secondary" size="sm">Settings</Button>
        </Link>
      </div>

      {/* Stats */}
      <div className="mb-8 grid grid-cols-3 gap-4">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-center">
          <p className="text-2xl font-bold text-[var(--color-primary)]">{watchlist.length}</p>
          <p className="text-xs text-[var(--color-text-muted)]">In Watchlist</p>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-center">
          <p className="text-2xl font-bold text-[var(--color-primary)]">{history.length}</p>
          <p className="text-xs text-[var(--color-text-muted)]">Watched</p>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-center">
          <p className="text-2xl font-bold text-[var(--color-primary)]">{continueWatching.length}</p>
          <p className="text-xs text-[var(--color-text-muted)]">In Progress</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="mb-6 flex gap-1 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-1">
        {tabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`flex-1 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
              tab === t.key
                ? "bg-[var(--color-primary)] text-white"
                : "text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      {loading ? (
        <div className="space-y-3">
          {Array.from({ length: 4 }, (_, i) => (
            <Skeleton key={i} className="h-20 w-full" />
          ))}
        </div>
      ) : tab === "watchlist" ? (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
          {watchlist.length === 0 ? (
            <p className="col-span-full text-center text-sm text-[var(--color-text-muted)]">
              Your watchlist is empty
            </p>
          ) : (
            watchlist.map((item) => (
              <Link
                key={item.id}
                href={item.animeId ? `/anime/${item.animeId}` : `/manga/${item.mangaId}`}
                className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3 transition-colors hover:bg-[var(--color-surface-hover)]"
              >
                <p className="text-sm font-medium text-[var(--color-text)] line-clamp-2">
                  {item.anime?.title || item.manga?.title || "Unknown"}
                </p>
                <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                  {item.animeId ? "Anime" : "Manga"}
                </p>
              </Link>
            ))
          )}
        </div>
      ) : tab === "history" ? (
        <div className="space-y-3">
          {history.length === 0 ? (
            <p className="text-center text-sm text-[var(--color-text-muted)]">
              No watch history yet
            </p>
          ) : (
            history.map((item) => (
              <div
                key={item.id}
                className="flex items-center gap-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3"
              >
                <div className="flex-1">
                  <p className="text-sm font-medium text-[var(--color-text)]">
                    {item.animeTitle || "Episode"}
                  </p>
                  <p className="text-xs text-[var(--color-text-muted)]">
                    Ep {item.episodeNumber} — {formatDuration(item.progressSeconds)}
                    {item.duration ? ` / ${formatDuration(item.duration)}` : ""}
                  </p>
                </div>
                <span className="text-xs text-[var(--color-text-muted)]">
                  {formatDate(item.watchedAt)}
                </span>
              </div>
            ))
          )}
        </div>
      ) : (
        <div className="space-y-3">
          {continueWatching.length === 0 ? (
            <p className="text-center text-sm text-[var(--color-text-muted)]">
              Nothing to continue
            </p>
          ) : (
            continueWatching.map((item) => (
              <Link
                key={item.id}
                href={`/anime/${item.animeId}/watch/${item.episodeId}`}
                className="flex items-center gap-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3 transition-colors hover:bg-[var(--color-surface-hover)]"
              >
                <div className="flex-1">
                  <p className="text-sm font-medium text-[var(--color-text)]">
                    {item.animeTitle || "Episode"}
                  </p>
                  <p className="text-xs text-[var(--color-text-muted)]">
                    Ep {item.episodeNumber} — {item.episodeTitle}
                  </p>
                  <div className="mt-1 h-1.5 w-full rounded-full bg-[var(--color-border)]">
                    <div
                      className="h-full rounded-full bg-[var(--color-primary)]"
                      style={{
                        width: `${item.duration ? (item.progressSeconds / item.duration) * 100 : 0}%`,
                      }}
                    />
                  </div>
                </div>
              </Link>
            ))
          )}
        </div>
      )}
    </div>
  );
}
