"use client";

import { useState, useEffect } from "react";
import { downloadService } from "@/services/download.service";
import { useSocket } from "@/contexts/SocketContext";
import { useToast } from "@/components/ui/Toast";
import { Button } from "@/components/ui/Button";
import { formatDate } from "@/lib/utils";
import type { Download, DownloadSettings } from "@/types/download";

type Tab = "queue" | "history" | "settings";

export default function DownloadsPage() {
  const { activeDownloads } = useSocket();
  const { toast } = useToast();
  const [tab, setTab] = useState<Tab>("queue");
  const [queue, setQueue] = useState<Download[]>([]);
  const [history, setHistory] = useState<Download[]>([]);
  const [settings, setSettings] = useState<DownloadSettings | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    try {
      const [q, h, s] = await Promise.all([
        downloadService.getQueue(),
        downloadService.getHistory(50),
        downloadService.getSettings(),
      ]);
      setQueue(q);
      setHistory(h);
      setSettings(s);
    } catch {
      toast("Failed to load downloads", "error");
    } finally {
      setLoading(false);
    }
  }

  // Merge WebSocket active downloads with REST queue
  const mergedQueue = [...queue];
  for (const ad of activeDownloads) {
    const idx = mergedQueue.findIndex((d) => d.id === ad.id);
    if (idx >= 0) mergedQueue[idx] = ad;
    else mergedQueue.push(ad);
  }

  async function handleCancel(id: string) {
    try {
      await downloadService.cancelDownload(id);
      setQueue((prev) => prev.filter((d) => d.id !== id));
      toast("Download cancelled", "info");
    } catch {
      toast("Failed to cancel download", "error");
    }
  }

  const tabs: { key: Tab; label: string }[] = [
    { key: "queue", label: "Queue" },
    { key: "history", label: "History" },
    { key: "settings", label: "Settings" },
  ];

  return (
    <div className="p-6">
      <h1 className="mb-6 text-2xl font-bold text-[var(--color-text)]">
        Downloads
      </h1>

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

      {loading ? (
        <p className="text-sm text-[var(--color-text-muted)]">Loading...</p>
      ) : tab === "queue" ? (
        <div className="space-y-3">
          {mergedQueue.length === 0 ? (
            <p className="text-center text-sm text-[var(--color-text-muted)]">
              No active downloads
            </p>
          ) : (
            mergedQueue.map((dl) => (
              <div
                key={dl.id}
                className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4"
              >
                <div className="mb-2 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-[var(--color-text)]">
                      {dl.animeName} — Ep {dl.episodeNumber}
                    </p>
                    <p className="text-xs text-[var(--color-text-muted)]">
                      {dl.status}
                    </p>
                  </div>
                  {(dl.status === "pending" || dl.status === "downloading") && (
                    <Button
                      variant="danger"
                      size="sm"
                      onClick={() => handleCancel(dl.id)}
                    >
                      Cancel
                    </Button>
                  )}
                </div>
                <div className="h-2 w-full rounded-full bg-[var(--color-border)]">
                  <div
                    className="h-full rounded-full bg-[var(--color-primary)] transition-all"
                    style={{ width: `${dl.progress}%` }}
                  />
                </div>
                <p className="mt-1 text-right text-xs text-[var(--color-text-muted)]">
                  {dl.progress}%
                </p>
              </div>
            ))
          )}
        </div>
      ) : tab === "history" ? (
        <div className="space-y-3">
          {history.length === 0 ? (
            <p className="text-center text-sm text-[var(--color-text-muted)]">
              No download history
            </p>
          ) : (
            history.map((dl) => (
              <div
                key={dl.id}
                className="flex items-center justify-between rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3"
              >
                <div>
                  <p className="text-sm font-medium text-[var(--color-text)]">
                    {dl.animeName} — Ep {dl.episodeNumber}
                  </p>
                  <p className="text-xs text-[var(--color-text-muted)]">
                    {dl.status} — {dl.completedAt ? formatDate(dl.completedAt) : ""}
                  </p>
                </div>
                <span
                  className={`rounded-full px-2 py-0.5 text-xs ${
                    dl.status === "completed"
                      ? "bg-[var(--color-success)]/20 text-[var(--color-success)]"
                      : "bg-[var(--color-danger)]/20 text-[var(--color-danger)]"
                  }`}
                >
                  {dl.status}
                </span>
              </div>
            ))
          )}
        </div>
      ) : (
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6">
          <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
            Download Settings
          </h2>
          <div className="space-y-4">
            <div>
              <label className="text-sm text-[var(--color-text-muted)]">
                Use Server Folder
              </label>
              <p className="text-sm text-[var(--color-text)]">
                {settings?.useServerFolder ? "Yes" : "No"}
              </p>
            </div>
            {settings?.serverFolderPath && (
              <div>
                <label className="text-sm text-[var(--color-text-muted)]">
                  Server Path
                </label>
                <p className="text-sm text-[var(--color-text)]">
                  {settings.serverFolderPath}
                </p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
