# Phase 6: Downloads, AI, Library & Premium — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Download manager with real-time WebSocket progress, AI chat + recommendations, local library browser, Stripe subscription checkout.

**Architecture:** Socket.IO client connects with JWT auth on login, disconnects on logout. SocketContext provides reactive download progress and history updates to all consumers. Downloads page has queue (real-time) + history tabs + settings panel. AI chat page renders message bubbles with inline anime recommendation cards. Library page is a folder browser with direct video streaming. Subscribe page shows current plan and redirects to Stripe Checkout for upgrades.

**Tech Stack:** Next.js 16, React 19, Tailwind CSS v4, TypeScript, socket.io-client

**Depends On:** Phase 5 (User & Social) — auth context, app shell, user profile, services layer all exist.

> **BACKEND GAPS:** The `monetization/` module currently has NO controller/endpoints — only internal services (`SubscriptionService`, `PaymentService`). Before implementing the Subscribe page, a `MonetizationController` must be added to the backend with `POST /monetization/checkout` and `POST /monetization/cancel` endpoints. The download, AI, library, and notification endpoints all exist and are ready.

---

## File Structure

```
web/
├── app/
│   └── (main)/
│       ├── downloads/page.tsx          # Download queue + history + settings
│       ├── chat/page.tsx               # AI chat with recommendation cards
│       ├── library/page.tsx            # Folder browser + video playback
│       └── subscribe/page.tsx          # Subscription plans + Stripe checkout
├── components/
│   ├── downloads/
│   │   ├── DownloadQueue.tsx           # Real-time queue with WebSocket progress
│   │   ├── DownloadProgress.tsx        # Single download item with progress bar
│   │   └── DownloadSettingsPanel.tsx   # Download path + server folder config
│   ├── chat/
│   │   ├── ChatBubble.tsx              # Message bubble (user/assistant)
│   │   └── ChatInput.tsx               # Text input with send button
│   └── library/
│       ├── FolderCard.tsx              # Folder grid item
│       └── VideoCard.tsx               # Video list item with play button
├── contexts/
│   └── SocketContext.tsx               # Socket.IO lifecycle tied to auth
├── services/
│   ├── socket.service.ts              # Socket.IO connect/disconnect/subscribe
│   ├── download.service.ts            # Download CRUD + queue + history + settings
│   ├── ai.service.ts                  # Chat + recommendations
│   ├── library.service.ts             # Folders + videos + stream URLs
│   └── subscription.service.ts        # Checkout + cancel + status
└── types/
    └── library.ts                     # Folder, Video, CheckoutSession, Subscription
```

---

### Task 1: Install socket.io-client Dependency

**Files:**
- Modify: `web/package.json`

- [ ] **Step 1: Install socket.io-client**

```bash
cd web
npm install socket.io-client
```

- [ ] **Step 2: Commit**

```bash
git add web/package.json web/package-lock.json
git commit -m "feat(web): install socket.io-client for real-time downloads"
```

---

### Task 2: Create Library & Subscription Type Definitions

**Files:**
- Create: `web/types/library.ts`

- [ ] **Step 1: Create `web/types/library.ts`**

```typescript
export interface Folder {
  id: string;
  name: string;
  path: string;
  videoCount: number;
  createdAt: string;
}

export interface Video {
  id: string;
  folderId: string;
  fileName: string;
  filePath: string;
  duration?: number;
  size?: number;
  thumbnail?: string;
  createdAt: string;
}

export interface CheckoutSession {
  sessionUrl: string;
  sessionId: string;
}

export interface Subscription {
  id: string;
  userId: string;
  tier: "free" | "premium";
  status: "active" | "cancelled" | "expired";
  startDate?: string;
  endDate?: string;
  stripeSubscriptionId?: string;
  stripeCustomerId?: string;
  amount: number;
  createdAt: string;
  updatedAt: string;
}
```

- [ ] **Step 2: Commit**

```bash
git add web/types/library.ts
git commit -m "feat(web): add library, video, checkout, subscription types"
```

---

### Task 3: Create Socket Service

**Files:**
- Create: `web/services/socket.service.ts`

- [ ] **Step 1: Create `web/services/socket.service.ts`**

```typescript
import { io, Socket } from "socket.io-client";
import type { Download } from "@/types/download";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:3005";

export interface DownloadProgressEvent {
  downloadId: string;
  status: Download["status"];
  progress: number;
  fileName?: string;
  errorMessage?: string;
}

export interface HistoryUpdatedEvent {
  type: "watch" | "reading";
  id: string;
}

class SocketService {
  private downloadSocket: Socket | null = null;
  private historySocket: Socket | null = null;

  connect(token: string): void {
    if (this.downloadSocket?.connected) return;

    this.downloadSocket = io(`${API_BASE_URL}/downloads`, {
      auth: { token },
      transports: ["websocket", "polling"],
      reconnection: true,
      reconnectionAttempts: 10,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
    });

    this.historySocket = io(`${API_BASE_URL}/history`, {
      auth: { token },
      transports: ["websocket", "polling"],
      reconnection: true,
      reconnectionAttempts: 10,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
    });

    this.downloadSocket.on("connect", () => {
      console.log("[SocketService] downloads namespace connected");
    });

    this.historySocket.on("connect", () => {
      console.log("[SocketService] history namespace connected");
    });

    this.downloadSocket.on("connect_error", (err) => {
      console.error("[SocketService] downloads connect error:", err.message);
    });

    this.historySocket.on("connect_error", (err) => {
      console.error("[SocketService] history connect error:", err.message);
    });
  }

  disconnect(): void {
    if (this.downloadSocket) {
      this.downloadSocket.disconnect();
      this.downloadSocket = null;
    }
    if (this.historySocket) {
      this.historySocket.disconnect();
      this.historySocket = null;
    }
    console.log("[SocketService] disconnected all namespaces");
  }

  onDownloadProgress(callback: (data: DownloadProgressEvent) => void): void {
    this.downloadSocket?.on("download_progress", callback);
  }

  offDownloadProgress(callback?: (data: DownloadProgressEvent) => void): void {
    if (callback) {
      this.downloadSocket?.off("download_progress", callback);
    } else {
      this.downloadSocket?.off("download_progress");
    }
  }

  onHistoryUpdated(callback: (data: HistoryUpdatedEvent) => void): void {
    this.historySocket?.on("history_updated", callback);
  }

  offHistoryUpdated(callback?: (data: HistoryUpdatedEvent) => void): void {
    if (callback) {
      this.historySocket?.off("history_updated", callback);
    } else {
      this.historySocket?.off("history_updated");
    }
  }

  get isConnected(): boolean {
    return this.downloadSocket?.connected ?? false;
  }
}

export const socketService = new SocketService();
```

- [ ] **Step 2: Commit**

```bash
git add web/services/socket.service.ts
git commit -m "feat(web): add socket service with download and history namespaces"
```

---

### Task 4: Create SocketContext

**Files:**
- Create: `web/contexts/SocketContext.tsx`

- [ ] **Step 1: Create `web/contexts/SocketContext.tsx`**

```typescript
"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  type ReactNode,
} from "react";
import {
  socketService,
  type DownloadProgressEvent,
  type HistoryUpdatedEvent,
} from "@/services/socket.service";
import { useAuth } from "@/contexts/AuthContext";

interface SocketContextValue {
  isConnected: boolean;
  downloadProgress: Map<string, DownloadProgressEvent>;
  lastHistoryUpdate: HistoryUpdatedEvent | null;
}

const SocketContext = createContext<SocketContextValue>({
  isConnected: false,
  downloadProgress: new Map(),
  lastHistoryUpdate: null,
});

export function SocketProvider({ children }: { children: ReactNode }) {
  const { user, token } = useAuth();
  const [isConnected, setIsConnected] = useState(false);
  const [downloadProgress, setDownloadProgress] = useState<
    Map<string, DownloadProgressEvent>
  >(new Map());
  const [lastHistoryUpdate, setLastHistoryUpdate] =
    useState<HistoryUpdatedEvent | null>(null);

  const handleDownloadProgress = useCallback(
    (data: DownloadProgressEvent) => {
      setDownloadProgress((prev) => {
        const next = new Map(prev);
        next.set(data.downloadId, data);

        if (
          data.status === "completed" ||
          data.status === "failed" ||
          data.status === "cancelled"
        ) {
          setTimeout(() => {
            setDownloadProgress((current) => {
              const updated = new Map(current);
              updated.delete(data.downloadId);
              return updated;
            });
          }, 5000);
        }

        return next;
      });
    },
    [],
  );

  const handleHistoryUpdated = useCallback((data: HistoryUpdatedEvent) => {
    setLastHistoryUpdate(data);
  }, []);

  useEffect(() => {
    if (user && token) {
      socketService.connect(token);
      setIsConnected(true);

      socketService.onDownloadProgress(handleDownloadProgress);
      socketService.onHistoryUpdated(handleHistoryUpdated);

      return () => {
        socketService.offDownloadProgress(handleDownloadProgress);
        socketService.offHistoryUpdated(handleHistoryUpdated);
        socketService.disconnect();
        setIsConnected(false);
        setDownloadProgress(new Map());
        setLastHistoryUpdate(null);
      };
    } else {
      socketService.disconnect();
      setIsConnected(false);
      setDownloadProgress(new Map());
      setLastHistoryUpdate(null);
    }
  }, [user, token, handleDownloadProgress, handleHistoryUpdated]);

  return (
    <SocketContext.Provider
      value={{ isConnected, downloadProgress, lastHistoryUpdate }}
    >
      {children}
    </SocketContext.Provider>
  );
}

export function useSocket() {
  return useContext(SocketContext);
}
```

- [ ] **Step 2: Register SocketProvider in root layout**

In `web/app/(main)/layout.tsx`, wrap the existing providers with `<SocketProvider>`:

```typescript
import { SocketProvider } from "@/contexts/SocketContext";

// Inside the layout's return, wrap children:
<SocketProvider>
  {/* existing content */}
</SocketProvider>
```

- [ ] **Step 3: Commit**

```bash
git add web/contexts/SocketContext.tsx web/app/\(main\)/layout.tsx
git commit -m "feat(web): add SocketContext with download progress and history updates"
```

---

### Task 5: Create Download Service

**Files:**
- Create: `web/services/download.service.ts`

- [ ] **Step 1: Create `web/services/download.service.ts`**

```typescript
import { apiClient } from "@/services/api-client";
import type { Download, DownloadSettings } from "@/types/download";

export interface DownloadFromUrlPayload {
  url: string;
  fileName?: string;
  animeId?: string;
  episodeId?: string;
}

export interface UpdateSettingsPayload {
  downloadPath?: string;
  useServerFolder?: boolean;
  serverFolderPath?: string;
}

class DownloadService {
  async downloadEpisode(
    animeId: string,
    episodeId: string,
    source?: string,
  ): Promise<Download> {
    return apiClient.post<Download>(
      `/download/episode/${animeId}/${episodeId}`,
      source ? { source } : undefined,
    );
  }

  async downloadSeason(
    animeId: string,
    season: number,
    source?: string,
  ): Promise<Download[]> {
    return apiClient.post<Download[]>(
      `/download/season/${animeId}/${season}`,
      source ? { source } : undefined,
    );
  }

  async downloadFromUrl(data: DownloadFromUrlPayload): Promise<Download> {
    return apiClient.post<Download>("/download/url", data);
  }

  async getQueue(): Promise<Download[]> {
    return apiClient.get<Download[]>("/download/queue");
  }

  async getHistory(limit?: number): Promise<Download[]> {
    return apiClient.get<Download[]>("/download/history", { limit });
  }

  async cancelDownload(id: string): Promise<void> {
    return apiClient.delete<void>(`/download/${id}`);
  }

  async deleteDownload(id: string): Promise<void> {
    return apiClient.delete<void>(`/download/${id}`);
  }

  async getSettings(): Promise<DownloadSettings> {
    return apiClient.get<DownloadSettings>("/download/settings");
  }

  async updateSettings(data: UpdateSettingsPayload): Promise<DownloadSettings> {
    return apiClient.put<DownloadSettings>("/download/settings", data);
  }
}

export const downloadService = new DownloadService();
```

- [ ] **Step 2: Commit**

```bash
git add web/services/download.service.ts
git commit -m "feat(web): add download service with queue, history, and settings"
```

---

### Task 6: Create DownloadProgress Component

**Files:**
- Create: `web/components/downloads/DownloadProgress.tsx`

- [ ] **Step 1: Create `web/components/downloads/DownloadProgress.tsx`**

```typescript
"use client";

import { useState } from "react";
import type { Download } from "@/types/download";
import type { DownloadProgressEvent } from "@/services/socket.service";

interface DownloadProgressProps {
  download: Download;
  realtimeProgress?: DownloadProgressEvent;
  onCancel: (id: string) => void;
}

export default function DownloadProgress({
  download,
  realtimeProgress,
  onCancel,
}: DownloadProgressProps) {
  const [cancelling, setCancelling] = useState(false);

  const progress = realtimeProgress?.progress ?? download.progress;
  const status = realtimeProgress?.status ?? download.status;

  const handleCancel = async () => {
    setCancelling(true);
    try {
      await onCancel(download.id);
    } finally {
      setCancelling(false);
    }
  };

  const statusColors: Record<string, string> = {
    pending: "text-yellow-400",
    downloading: "text-[var(--color-primary)]",
    completed: "text-[var(--color-success)]",
    failed: "text-[var(--color-danger)]",
    cancelled: "text-[var(--color-text-muted)]",
  };

  const progressBarColors: Record<string, string> = {
    pending: "bg-yellow-400",
    downloading: "bg-[var(--color-primary)]",
    completed: "bg-[var(--color-success)]",
    failed: "bg-[var(--color-danger)]",
    cancelled: "bg-[var(--color-text-muted)]",
  };

  return (
    <div className="flex items-center gap-4 rounded-lg bg-[var(--color-surface)] p-4 border border-[var(--color-border)]">
      {/* Thumbnail */}
      <div className="hidden sm:block h-16 w-16 flex-shrink-0 rounded-md bg-[var(--color-surface-hover)] overflow-hidden">
        {download.thumbnailUrl ? (
          <img
            src={download.thumbnailUrl}
            alt={download.episodeTitle ?? `Episode ${download.episodeNumber}`}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-[var(--color-text-muted)]">
            <svg
              className="h-6 w-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M7 4v16l13-8L7 4z"
              />
            </svg>
          </div>
        )}
      </div>

      {/* Info + Progress */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-2 mb-1">
          <div className="min-w-0">
            <p className="text-sm font-medium text-[var(--color-text)] truncate">
              {download.animeName}
            </p>
            <p className="text-xs text-[var(--color-text-muted)] truncate">
              Episode {download.episodeNumber}
              {download.episodeTitle ? ` — ${download.episodeTitle}` : ""}
            </p>
          </div>
          <span
            className={`text-xs font-medium capitalize whitespace-nowrap ${statusColors[status] ?? ""}`}
          >
            {status}
          </span>
        </div>

        {/* Progress bar */}
        <div className="w-full h-2 rounded-full bg-[var(--color-border)] overflow-hidden">
          <div
            className={`h-full rounded-full transition-all duration-300 ${progressBarColors[status] ?? "bg-[var(--color-primary)]"}`}
            style={{ width: `${Math.min(progress, 100)}%` }}
          />
        </div>

        <div className="flex items-center justify-between mt-1">
          <span className="text-xs text-[var(--color-text-muted)]">
            {Math.round(progress)}%
          </span>
          {realtimeProgress?.errorMessage && (
            <span className="text-xs text-[var(--color-danger)] truncate max-w-[200px]">
              {realtimeProgress.errorMessage}
            </span>
          )}
        </div>
      </div>

      {/* Cancel button */}
      {(status === "pending" || status === "downloading") && (
        <button
          onClick={handleCancel}
          disabled={cancelling}
          className="flex-shrink-0 rounded-md p-2 text-[var(--color-text-muted)] hover:text-[var(--color-danger)] hover:bg-[var(--color-surface-hover)] transition-colors disabled:opacity-50"
          title="Cancel download"
        >
          {cancelling ? (
            <svg
              className="h-5 w-5 animate-spin"
              fill="none"
              viewBox="0 0 24 24"
            >
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
          ) : (
            <svg
              className="h-5 w-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          )}
        </button>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/downloads/DownloadProgress.tsx
git commit -m "feat(web): add DownloadProgress component with real-time progress bar"
```

---

### Task 7: Create DownloadQueue Component

**Files:**
- Create: `web/components/downloads/DownloadQueue.tsx`

- [ ] **Step 1: Create `web/components/downloads/DownloadQueue.tsx`**

```typescript
"use client";

import { useEffect, useState, useCallback } from "react";
import { downloadService } from "@/services/download.service";
import { useSocket } from "@/contexts/SocketContext";
import DownloadProgress from "@/components/downloads/DownloadProgress";
import type { Download } from "@/types/download";

export default function DownloadQueue() {
  const { downloadProgress } = useSocket();
  const [queue, setQueue] = useState<Download[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchQueue = useCallback(async () => {
    try {
      setError(null);
      const data = await downloadService.getQueue();
      setQueue(data);
    } catch {
      setError("Failed to load download queue");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchQueue();
  }, [fetchQueue]);

  // Re-fetch queue when a download completes or fails via WebSocket
  useEffect(() => {
    const completedOrFailed = Array.from(downloadProgress.values()).filter(
      (p) =>
        p.status === "completed" ||
        p.status === "failed" ||
        p.status === "cancelled",
    );
    if (completedOrFailed.length > 0) {
      const timeout = setTimeout(fetchQueue, 2000);
      return () => clearTimeout(timeout);
    }
  }, [downloadProgress, fetchQueue]);

  const handleCancel = async (id: string) => {
    try {
      await downloadService.cancelDownload(id);
      setQueue((prev) => prev.filter((d) => d.id !== id));
    } catch {
      setError("Failed to cancel download");
    }
  };

  if (loading) {
    return (
      <div className="space-y-3">
        {[1, 2, 3].map((i) => (
          <div
            key={i}
            className="h-24 animate-pulse rounded-lg bg-[var(--color-surface)]"
          />
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg bg-[var(--color-surface)] p-6 text-center">
        <p className="text-[var(--color-danger)]">{error}</p>
        <button
          onClick={fetchQueue}
          className="mt-3 text-sm text-[var(--color-primary)] hover:underline"
        >
          Retry
        </button>
      </div>
    );
  }

  if (queue.length === 0) {
    return (
      <div className="rounded-lg bg-[var(--color-surface)] border border-[var(--color-border)] p-8 text-center">
        <svg
          className="mx-auto h-12 w-12 text-[var(--color-text-muted)]"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={1.5}
            d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
          />
        </svg>
        <p className="mt-3 text-[var(--color-text-muted)]">
          No active downloads
        </p>
        <p className="mt-1 text-xs text-[var(--color-text-muted)]">
          Downloads you start will appear here with real-time progress
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {queue.map((download) => (
        <DownloadProgress
          key={download.id}
          download={download}
          realtimeProgress={downloadProgress.get(download.id)}
          onCancel={handleCancel}
        />
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/downloads/DownloadQueue.tsx
git commit -m "feat(web): add DownloadQueue with real-time WebSocket progress"
```

---

### Task 8: Create DownloadSettingsPanel Component

**Files:**
- Create: `web/components/downloads/DownloadSettingsPanel.tsx`

- [ ] **Step 1: Create `web/components/downloads/DownloadSettingsPanel.tsx`**

```typescript
"use client";

import { useEffect, useState } from "react";
import {
  downloadService,
  type UpdateSettingsPayload,
} from "@/services/download.service";
import type { DownloadSettings } from "@/types/download";

export default function DownloadSettingsPanel() {
  const [settings, setSettings] = useState<DownloadSettings | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const [downloadPath, setDownloadPath] = useState("");
  const [useServerFolder, setUseServerFolder] = useState(false);
  const [serverFolderPath, setServerFolderPath] = useState("");

  useEffect(() => {
    const fetchSettings = async () => {
      try {
        const data = await downloadService.getSettings();
        setSettings(data);
        setDownloadPath(data.downloadPath ?? "");
        setUseServerFolder(data.useServerFolder);
        setServerFolderPath(data.serverFolderPath ?? "");
      } catch {
        setError("Failed to load download settings");
      } finally {
        setLoading(false);
      }
    };
    fetchSettings();
  }, []);

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    setSuccess(false);
    try {
      const payload: UpdateSettingsPayload = {
        downloadPath: downloadPath || undefined,
        useServerFolder,
        serverFolderPath: serverFolderPath || undefined,
      };
      const updated = await downloadService.updateSettings(payload);
      setSettings(updated);
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch {
      setError("Failed to save settings");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="animate-pulse rounded-lg bg-[var(--color-surface)] p-6 h-48" />
    );
  }

  return (
    <div className="rounded-lg bg-[var(--color-surface)] border border-[var(--color-border)] p-6">
      <h3 className="text-lg font-semibold text-[var(--color-text)] mb-4">
        Download Settings
      </h3>

      <div className="space-y-4">
        {/* Download path */}
        <div>
          <label
            htmlFor="downloadPath"
            className="block text-sm font-medium text-[var(--color-text-muted)] mb-1"
          >
            Download Path
          </label>
          <input
            id="downloadPath"
            type="text"
            value={downloadPath}
            onChange={(e) => setDownloadPath(e.target.value)}
            placeholder="/path/to/downloads"
            className="w-full rounded-md bg-[var(--color-bg)] border border-[var(--color-border)] px-3 py-2 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] focus:border-transparent"
          />
        </div>

        {/* Use server folder toggle */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            role="switch"
            aria-checked={useServerFolder}
            onClick={() => setUseServerFolder(!useServerFolder)}
            className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ${
              useServerFolder
                ? "bg-[var(--color-primary)]"
                : "bg-[var(--color-border)]"
            }`}
          >
            <span
              className={`pointer-events-none inline-block h-5 w-5 rounded-full bg-white shadow transform transition-transform duration-200 ${
                useServerFolder ? "translate-x-5" : "translate-x-0"
              }`}
            />
          </button>
          <label className="text-sm text-[var(--color-text)]">
            Use server folder for downloads
          </label>
        </div>

        {/* Server folder path */}
        {useServerFolder && (
          <div>
            <label
              htmlFor="serverFolderPath"
              className="block text-sm font-medium text-[var(--color-text-muted)] mb-1"
            >
              Server Folder Path
            </label>
            <input
              id="serverFolderPath"
              type="text"
              value={serverFolderPath}
              onChange={(e) => setServerFolderPath(e.target.value)}
              placeholder="/server/media/anime"
              className="w-full rounded-md bg-[var(--color-bg)] border border-[var(--color-border)] px-3 py-2 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] focus:border-transparent"
            />
          </div>
        )}

        {/* Last updated */}
        {settings?.updatedAt && (
          <p className="text-xs text-[var(--color-text-muted)]">
            Last updated:{" "}
            {new Date(settings.updatedAt).toLocaleDateString("en-US", {
              year: "numeric",
              month: "short",
              day: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            })}
          </p>
        )}

        {/* Error / Success */}
        {error && (
          <p className="text-sm text-[var(--color-danger)]">{error}</p>
        )}
        {success && (
          <p className="text-sm text-[var(--color-success)]">
            Settings saved successfully
          </p>
        )}

        {/* Save button */}
        <button
          onClick={handleSave}
          disabled={saving}
          className="rounded-md bg-[var(--color-primary)] px-4 py-2 text-sm font-medium text-white hover:bg-[var(--color-primary-hover)] transition-colors disabled:opacity-50"
        >
          {saving ? "Saving..." : "Save Settings"}
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/downloads/DownloadSettingsPanel.tsx
git commit -m "feat(web): add DownloadSettingsPanel with path and server folder config"
```

---

### Task 9: Create Downloads Page

**Files:**
- Create: `web/app/(main)/downloads/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/downloads/page.tsx`**

```typescript
"use client";

import { useState, useEffect, useCallback } from "react";
import DownloadQueue from "@/components/downloads/DownloadQueue";
import DownloadProgress from "@/components/downloads/DownloadProgress";
import DownloadSettingsPanel from "@/components/downloads/DownloadSettingsPanel";
import { downloadService } from "@/services/download.service";
import { useSocket } from "@/contexts/SocketContext";
import type { Download } from "@/types/download";

type Tab = "queue" | "history" | "settings";

export default function DownloadsPage() {
  const { isConnected } = useSocket();
  const [activeTab, setActiveTab] = useState<Tab>("queue");
  const [history, setHistory] = useState<Download[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState<string | null>(null);

  // URL download form
  const [showUrlForm, setShowUrlForm] = useState(false);
  const [downloadUrl, setDownloadUrl] = useState("");
  const [downloadFileName, setDownloadFileName] = useState("");
  const [urlSubmitting, setUrlSubmitting] = useState(false);

  const fetchHistory = useCallback(async () => {
    setHistoryLoading(true);
    setHistoryError(null);
    try {
      const data = await downloadService.getHistory(50);
      setHistory(data);
    } catch {
      setHistoryError("Failed to load download history");
    } finally {
      setHistoryLoading(false);
    }
  }, []);

  useEffect(() => {
    if (activeTab === "history") {
      fetchHistory();
    }
  }, [activeTab, fetchHistory]);

  const handleDeleteHistory = async (id: string) => {
    try {
      await downloadService.deleteDownload(id);
      setHistory((prev) => prev.filter((d) => d.id !== id));
    } catch {
      // silent fail
    }
  };

  const handleUrlDownload = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!downloadUrl.trim()) return;
    setUrlSubmitting(true);
    try {
      await downloadService.downloadFromUrl({
        url: downloadUrl,
        fileName: downloadFileName || undefined,
      });
      setDownloadUrl("");
      setDownloadFileName("");
      setShowUrlForm(false);
    } catch {
      // Error handled by toast in production
    } finally {
      setUrlSubmitting(false);
    }
  };

  const tabs: { key: Tab; label: string }[] = [
    { key: "queue", label: "Queue" },
    { key: "history", label: "History" },
    { key: "settings", label: "Settings" },
  ];

  return (
    <div className="mx-auto max-w-4xl px-4 py-6 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-[var(--color-text)]">
            Downloads
          </h1>
          <div className="flex items-center gap-2 mt-1">
            <span
              className={`inline-block h-2 w-2 rounded-full ${isConnected ? "bg-[var(--color-success)]" : "bg-[var(--color-danger)]"}`}
            />
            <span className="text-xs text-[var(--color-text-muted)]">
              {isConnected ? "Real-time updates active" : "Disconnected"}
            </span>
          </div>
        </div>

        <button
          onClick={() => setShowUrlForm(!showUrlForm)}
          className="rounded-md bg-[var(--color-primary)] px-4 py-2 text-sm font-medium text-white hover:bg-[var(--color-primary-hover)] transition-colors"
        >
          Download from URL
        </button>
      </div>

      {/* URL Download Form */}
      {showUrlForm && (
        <form
          onSubmit={handleUrlDownload}
          className="mb-6 rounded-lg bg-[var(--color-surface)] border border-[var(--color-border)] p-4"
        >
          <div className="space-y-3">
            <div>
              <label
                htmlFor="url"
                className="block text-sm font-medium text-[var(--color-text-muted)] mb-1"
              >
                Video URL
              </label>
              <input
                id="url"
                type="url"
                value={downloadUrl}
                onChange={(e) => setDownloadUrl(e.target.value)}
                placeholder="https://example.com/video.mp4"
                required
                className="w-full rounded-md bg-[var(--color-bg)] border border-[var(--color-border)] px-3 py-2 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]"
              />
            </div>
            <div>
              <label
                htmlFor="fileName"
                className="block text-sm font-medium text-[var(--color-text-muted)] mb-1"
              >
                File Name (optional)
              </label>
              <input
                id="fileName"
                type="text"
                value={downloadFileName}
                onChange={(e) => setDownloadFileName(e.target.value)}
                placeholder="my-video.mp4"
                className="w-full rounded-md bg-[var(--color-bg)] border border-[var(--color-border)] px-3 py-2 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]"
              />
            </div>
            <div className="flex gap-2">
              <button
                type="submit"
                disabled={urlSubmitting}
                className="rounded-md bg-[var(--color-primary)] px-4 py-2 text-sm font-medium text-white hover:bg-[var(--color-primary-hover)] transition-colors disabled:opacity-50"
              >
                {urlSubmitting ? "Starting..." : "Start Download"}
              </button>
              <button
                type="button"
                onClick={() => setShowUrlForm(false)}
                className="rounded-md bg-[var(--color-surface-hover)] px-4 py-2 text-sm text-[var(--color-text-muted)] hover:text-[var(--color-text)] transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </form>
      )}

      {/* Tabs */}
      <div className="flex gap-1 mb-6 border-b border-[var(--color-border)]">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px ${
              activeTab === tab.key
                ? "border-[var(--color-primary)] text-[var(--color-primary)]"
                : "border-transparent text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      {activeTab === "queue" && <DownloadQueue />}

      {activeTab === "history" && (
        <div>
          {historyLoading ? (
            <div className="space-y-3">
              {[1, 2, 3].map((i) => (
                <div
                  key={i}
                  className="h-24 animate-pulse rounded-lg bg-[var(--color-surface)]"
                />
              ))}
            </div>
          ) : historyError ? (
            <div className="rounded-lg bg-[var(--color-surface)] p-6 text-center">
              <p className="text-[var(--color-danger)]">{historyError}</p>
              <button
                onClick={fetchHistory}
                className="mt-3 text-sm text-[var(--color-primary)] hover:underline"
              >
                Retry
              </button>
            </div>
          ) : history.length === 0 ? (
            <div className="rounded-lg bg-[var(--color-surface)] border border-[var(--color-border)] p-8 text-center">
              <p className="text-[var(--color-text-muted)]">
                No download history yet
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {history.map((download) => (
                <DownloadProgress
                  key={download.id}
                  download={download}
                  onCancel={handleDeleteHistory}
                />
              ))}
            </div>
          )}
        </div>
      )}

      {activeTab === "settings" && <DownloadSettingsPanel />}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/downloads/page.tsx
git commit -m "feat(web): add downloads page with queue, history, URL download, and settings tabs"
```

---

### Task 10: Create AI Service

**Files:**
- Create: `web/services/ai.service.ts`

- [ ] **Step 1: Create `web/services/ai.service.ts`**

```typescript
import { apiClient } from "@/services/api-client";
import type { ChatMessage, AiRecommendationResponse } from "@/types/chat";

export interface ChatPayload {
  messages: { role: "user" | "assistant"; content: string }[];
}

class AiService {
  async sendChat(messages: ChatPayload["messages"]): Promise<ChatMessage> {
    return apiClient.post<ChatMessage>("/ai/chat", { messages });
  }

  async getRecommendations(
    message: string,
  ): Promise<AiRecommendationResponse> {
    return apiClient.post<AiRecommendationResponse>("/ai/recommend", {
      message,
    });
  }
}

export const aiService = new AiService();
```

- [ ] **Step 2: Commit**

```bash
git add web/services/ai.service.ts
git commit -m "feat(web): add AI service for chat and recommendations"
```

---

### Task 11: Create ChatBubble Component

**Files:**
- Create: `web/components/chat/ChatBubble.tsx`

- [ ] **Step 1: Create `web/components/chat/ChatBubble.tsx`**

```typescript
"use client";

import type { ChatMessage } from "@/types/chat";
import type { Anime } from "@/types/anime";
import Link from "next/link";

interface ChatBubbleProps {
  message: ChatMessage;
}

function AnimeRecommendationCard({ anime }: { anime: Anime }) {
  return (
    <Link
      href={`/anime/${anime.id}`}
      className="flex gap-3 rounded-lg bg-[var(--color-bg)] border border-[var(--color-border)] p-3 hover:border-[var(--color-primary)] transition-colors"
    >
      {anime.coverUrl && (
        <img
          src={anime.coverUrl}
          alt={anime.title}
          className="h-20 w-14 flex-shrink-0 rounded-md object-cover"
        />
      )}
      <div className="min-w-0">
        <p className="text-sm font-medium text-[var(--color-text)] truncate">
          {anime.title}
        </p>
        {anime.titleEnglish && anime.titleEnglish !== anime.title && (
          <p className="text-xs text-[var(--color-text-muted)] truncate">
            {anime.titleEnglish}
          </p>
        )}
        <div className="flex items-center gap-2 mt-1">
          {anime.rating > 0 && (
            <span className="text-xs text-yellow-400">
              {anime.rating.toFixed(1)}
            </span>
          )}
          <span className="text-xs text-[var(--color-text-muted)] capitalize">
            {anime.status}
          </span>
          {anime.totalEpisodes > 0 && (
            <span className="text-xs text-[var(--color-text-muted)]">
              {anime.totalEpisodes} eps
            </span>
          )}
        </div>
        {anime.genres.length > 0 && (
          <div className="flex flex-wrap gap-1 mt-1">
            {anime.genres.slice(0, 3).map((genre) => (
              <span
                key={genre}
                className="rounded-full bg-[var(--color-surface-hover)] px-2 py-0.5 text-[10px] text-[var(--color-text-muted)]"
              >
                {genre}
              </span>
            ))}
          </div>
        )}
      </div>
    </Link>
  );
}

export default function ChatBubble({ message }: ChatBubbleProps) {
  const isUser = message.isUser;

  return (
    <div
      className={`flex ${isUser ? "justify-end" : "justify-start"} mb-4`}
    >
      <div
        className={`max-w-[85%] sm:max-w-[70%] rounded-2xl px-4 py-3 ${
          isUser
            ? "bg-[var(--color-primary)] text-white rounded-br-md"
            : "bg-[var(--color-surface)] border border-[var(--color-border)] text-[var(--color-text)] rounded-bl-md"
        }`}
      >
        {/* Message content */}
        <p className="text-sm whitespace-pre-wrap leading-relaxed">
          {message.content}
        </p>

        {/* Recommendation cards */}
        {message.recommendations && message.recommendations.length > 0 && (
          <div className="mt-3 space-y-2">
            <p className="text-xs font-medium text-[var(--color-text-muted)] mb-2">
              Recommended anime:
            </p>
            {message.recommendations.map((anime) => (
              <AnimeRecommendationCard key={anime.id} anime={anime} />
            ))}
          </div>
        )}

        {/* Timestamp */}
        <p
          className={`text-[10px] mt-1 ${
            isUser ? "text-white/60" : "text-[var(--color-text-muted)]"
          }`}
        >
          {new Date(message.timestamp).toLocaleTimeString("en-US", {
            hour: "2-digit",
            minute: "2-digit",
          })}
        </p>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/chat/ChatBubble.tsx
git commit -m "feat(web): add ChatBubble component with anime recommendation cards"
```

---

### Task 12: Create ChatInput Component

**Files:**
- Create: `web/components/chat/ChatInput.tsx`

- [ ] **Step 1: Create `web/components/chat/ChatInput.tsx`**

```typescript
"use client";

import { useState, useRef, useEffect } from "react";

interface ChatInputProps {
  onSend: (message: string) => void;
  disabled?: boolean;
  placeholder?: string;
}

export default function ChatInput({
  onSend,
  disabled = false,
  placeholder = "Ask me about anime...",
}: ChatInputProps) {
  const [message, setMessage] = useState("");
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Auto-resize textarea
  useEffect(() => {
    const textarea = textareaRef.current;
    if (textarea) {
      textarea.style.height = "auto";
      textarea.style.height = `${Math.min(textarea.scrollHeight, 120)}px`;
    }
  }, [message]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = message.trim();
    if (!trimmed || disabled) return;
    onSend(trimmed);
    setMessage("");
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  return (
    <form
      onSubmit={handleSubmit}
      className="flex items-end gap-2 border-t border-[var(--color-border)] bg-[var(--color-surface)] p-4"
    >
      <textarea
        ref={textareaRef}
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        disabled={disabled}
        rows={1}
        className="flex-1 resize-none rounded-xl bg-[var(--color-bg)] border border-[var(--color-border)] px-4 py-2.5 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] focus:border-transparent disabled:opacity-50"
      />
      <button
        type="submit"
        disabled={disabled || !message.trim()}
        className="flex-shrink-0 rounded-xl bg-[var(--color-primary)] p-2.5 text-white hover:bg-[var(--color-primary-hover)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        title="Send message"
      >
        <svg
          className="h-5 w-5"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
          />
        </svg>
      </button>
    </form>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/chat/ChatInput.tsx
git commit -m "feat(web): add ChatInput component with auto-resize and Enter to send"
```

---

### Task 13: Create Chat Page

**Files:**
- Create: `web/app/(main)/chat/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/chat/page.tsx`**

```typescript
"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import ChatBubble from "@/components/chat/ChatBubble";
import ChatInput from "@/components/chat/ChatInput";
import { aiService } from "@/services/ai.service";
import type { ChatMessage } from "@/types/chat";

export default function ChatPage() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const isRecommendationQuery = (text: string): boolean => {
    const keywords = [
      "recommend",
      "suggestion",
      "suggest",
      "similar to",
      "like",
      "what should i watch",
      "what anime",
      "find me",
      "looking for",
    ];
    const lower = text.toLowerCase();
    return keywords.some((kw) => lower.includes(kw));
  };

  const handleSend = useCallback(
    async (text: string) => {
      const userMessage: ChatMessage = {
        id: `user-${Date.now()}`,
        content: text,
        isUser: true,
        timestamp: new Date().toISOString(),
      };

      setMessages((prev) => [...prev, userMessage]);
      setLoading(true);

      try {
        if (isRecommendationQuery(text)) {
          const response = await aiService.getRecommendations(text);
          const assistantMessage: ChatMessage = {
            id: `assistant-${Date.now()}`,
            content: response.explanation,
            isUser: false,
            timestamp: new Date().toISOString(),
            recommendations: response.recommendations,
          };
          setMessages((prev) => [...prev, assistantMessage]);
        } else {
          const chatHistory = [
            ...messages.map((m) => ({
              role: (m.isUser ? "user" : "assistant") as "user" | "assistant",
              content: m.content,
            })),
            { role: "user" as const, content: text },
          ];
          const response = await aiService.sendChat(chatHistory);
          setMessages((prev) => [
            ...prev,
            { ...response, id: response.id || `assistant-${Date.now()}` },
          ]);
        }
      } catch {
        const errorMessage: ChatMessage = {
          id: `error-${Date.now()}`,
          content:
            "Sorry, something went wrong. Please try again.",
          isUser: false,
          timestamp: new Date().toISOString(),
        };
        setMessages((prev) => [...prev, errorMessage]);
      } finally {
        setLoading(false);
      }
    },
    [messages],
  );

  return (
    <div className="flex h-[calc(100vh-4rem)] flex-col mx-auto max-w-3xl">
      {/* Header */}
      <div className="flex-shrink-0 border-b border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-3">
        <h1 className="text-lg font-semibold text-[var(--color-text)]">
          AI Assistant
        </h1>
        <p className="text-xs text-[var(--color-text-muted)]">
          Ask about anime, get recommendations, or chat about your favorites
        </p>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4">
        {messages.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center text-center">
            <svg
              className="h-16 w-16 text-[var(--color-text-muted)] mb-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1}
                d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"
              />
            </svg>
            <p className="text-[var(--color-text-muted)] mb-2">
              Start a conversation
            </p>
            <div className="space-y-2 text-sm text-[var(--color-text-muted)]">
              <p>Try asking:</p>
              <div className="flex flex-wrap justify-center gap-2">
                {[
                  "Recommend anime like Attack on Titan",
                  "What are the best anime of 2025?",
                  "Suggest a relaxing slice-of-life anime",
                  "What is Jujutsu Kaisen about?",
                ].map((suggestion) => (
                  <button
                    key={suggestion}
                    onClick={() => handleSend(suggestion)}
                    className="rounded-full bg-[var(--color-surface)] border border-[var(--color-border)] px-3 py-1.5 text-xs hover:border-[var(--color-primary)] hover:text-[var(--color-primary)] transition-colors"
                  >
                    {suggestion}
                  </button>
                ))}
              </div>
            </div>
          </div>
        ) : (
          <>
            {messages.map((msg) => (
              <ChatBubble key={msg.id} message={msg} />
            ))}
            {loading && (
              <div className="flex justify-start mb-4">
                <div className="rounded-2xl rounded-bl-md bg-[var(--color-surface)] border border-[var(--color-border)] px-4 py-3">
                  <div className="flex items-center gap-1">
                    <span className="h-2 w-2 rounded-full bg-[var(--color-text-muted)] animate-bounce" />
                    <span
                      className="h-2 w-2 rounded-full bg-[var(--color-text-muted)] animate-bounce"
                      style={{ animationDelay: "0.1s" }}
                    />
                    <span
                      className="h-2 w-2 rounded-full bg-[var(--color-text-muted)] animate-bounce"
                      style={{ animationDelay: "0.2s" }}
                    />
                  </div>
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </>
        )}
      </div>

      {/* Input */}
      <div className="flex-shrink-0">
        <ChatInput onSend={handleSend} disabled={loading} />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/chat/page.tsx
git commit -m "feat(web): add AI chat page with recommendation detection and inline cards"
```

---

### Task 14: Create Library Service

**Files:**
- Create: `web/services/library.service.ts`

- [ ] **Step 1: Create `web/services/library.service.ts`**

```typescript
import { apiClient } from "@/services/api-client";
import type { Folder, Video } from "@/types/library";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:3005";

class LibraryService {
  async getFolders(): Promise<Folder[]> {
    return apiClient.get<Folder[]>("/library/folders");
  }

  async getFolderVideos(folderId: string): Promise<Video[]> {
    return apiClient.get<Video[]>(`/library/folder/${folderId}/videos`);
  }

  getDirectStreamUrl(videoId: string): string {
    const token =
      typeof window !== "undefined"
        ? localStorage.getItem("auth_token")
        : null;
    return `${API_BASE_URL}/library/stream/${videoId}/direct${token ? `?token=${token}` : ""}`;
  }

  async organizeLibrary(): Promise<{ organized: number }> {
    return apiClient.post<{ organized: number }>("/library/organize");
  }
}

export const libraryService = new LibraryService();
```

- [ ] **Step 2: Commit**

```bash
git add web/services/library.service.ts
git commit -m "feat(web): add library service for folders, videos, and direct streaming"
```

---

### Task 15: Create Library Page Components

**Files:**
- Create: `web/components/library/FolderCard.tsx`
- Create: `web/components/library/VideoCard.tsx`

- [ ] **Step 1: Create `web/components/library/FolderCard.tsx`**

```typescript
"use client";

import type { Folder } from "@/types/library";

interface FolderCardProps {
  folder: Folder;
  onClick: (folder: Folder) => void;
}

export default function FolderCard({ folder, onClick }: FolderCardProps) {
  return (
    <button
      onClick={() => onClick(folder)}
      className="flex flex-col items-center gap-2 rounded-lg bg-[var(--color-surface)] border border-[var(--color-border)] p-4 hover:border-[var(--color-primary)] hover:bg-[var(--color-surface-hover)] transition-colors text-left w-full"
    >
      <svg
        className="h-12 w-12 text-[var(--color-primary)]"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={1.5}
          d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
        />
      </svg>
      <div className="text-center min-w-0 w-full">
        <p className="text-sm font-medium text-[var(--color-text)] truncate">
          {folder.name}
        </p>
        <p className="text-xs text-[var(--color-text-muted)]">
          {folder.videoCount} video{folder.videoCount !== 1 ? "s" : ""}
        </p>
      </div>
    </button>
  );
}
```

- [ ] **Step 2: Create `web/components/library/VideoCard.tsx`**

```typescript
"use client";

import type { Video } from "@/types/library";

interface VideoCardProps {
  video: Video;
  onPlay: (video: Video) => void;
}

function formatFileSize(bytes?: number): string {
  if (!bytes) return "";
  const units = ["B", "KB", "MB", "GB"];
  let size = bytes;
  let unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return `${size.toFixed(1)} ${units[unitIndex]}`;
}

function formatDuration(seconds?: number): string {
  if (!seconds) return "";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export default function VideoCard({ video, onPlay }: VideoCardProps) {
  return (
    <div className="flex items-center gap-4 rounded-lg bg-[var(--color-surface)] border border-[var(--color-border)] p-3 hover:border-[var(--color-primary)] transition-colors">
      {/* Thumbnail / Play button */}
      <button
        onClick={() => onPlay(video)}
        className="relative flex-shrink-0 h-16 w-24 rounded-md bg-[var(--color-surface-hover)] overflow-hidden group"
      >
        {video.thumbnail ? (
          <img
            src={video.thumbnail}
            alt={video.fileName}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center">
            <svg
              className="h-8 w-8 text-[var(--color-text-muted)] group-hover:text-[var(--color-primary)] transition-colors"
              fill="currentColor"
              viewBox="0 0 24 24"
            >
              <path d="M8 5v14l11-7z" />
            </svg>
          </div>
        )}
        <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
          <svg
            className="h-8 w-8 text-white"
            fill="currentColor"
            viewBox="0 0 24 24"
          >
            <path d="M8 5v14l11-7z" />
          </svg>
        </div>
      </button>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-[var(--color-text)] truncate">
          {video.fileName}
        </p>
        <div className="flex items-center gap-3 mt-1">
          {video.duration && (
            <span className="text-xs text-[var(--color-text-muted)]">
              {formatDuration(video.duration)}
            </span>
          )}
          {video.size && (
            <span className="text-xs text-[var(--color-text-muted)]">
              {formatFileSize(video.size)}
            </span>
          )}
        </div>
      </div>

      {/* Play button */}
      <button
        onClick={() => onPlay(video)}
        className="flex-shrink-0 rounded-full bg-[var(--color-primary)] p-2 text-white hover:bg-[var(--color-primary-hover)] transition-colors"
        title="Play video"
      >
        <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
          <path d="M8 5v14l11-7z" />
        </svg>
      </button>
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add web/components/library/FolderCard.tsx web/components/library/VideoCard.tsx
git commit -m "feat(web): add FolderCard and VideoCard components for library browser"
```

---

### Task 16: Create Library Page

**Files:**
- Create: `web/app/(main)/library/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/library/page.tsx`**

```typescript
"use client";

import { useState, useEffect, useCallback } from "react";
import FolderCard from "@/components/library/FolderCard";
import VideoCard from "@/components/library/VideoCard";
import { libraryService } from "@/services/library.service";
import type { Folder, Video } from "@/types/library";

export default function LibraryPage() {
  const [folders, setFolders] = useState<Folder[]>([]);
  const [selectedFolder, setSelectedFolder] = useState<Folder | null>(null);
  const [videos, setVideos] = useState<Video[]>([]);
  const [loading, setLoading] = useState(true);
  const [videosLoading, setVideosLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [playingVideo, setPlayingVideo] = useState<Video | null>(null);
  const [organizing, setOrganizing] = useState(false);

  const fetchFolders = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await libraryService.getFolders();
      setFolders(data);
    } catch {
      setError("Failed to load library folders");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchFolders();
  }, [fetchFolders]);

  const handleFolderClick = async (folder: Folder) => {
    setSelectedFolder(folder);
    setPlayingVideo(null);
    setVideosLoading(true);
    try {
      const data = await libraryService.getFolderVideos(folder.id);
      setVideos(data);
    } catch {
      setError("Failed to load videos");
    } finally {
      setVideosLoading(false);
    }
  };

  const handleBackToFolders = () => {
    setSelectedFolder(null);
    setVideos([]);
    setPlayingVideo(null);
  };

  const handlePlayVideo = (video: Video) => {
    setPlayingVideo(video);
  };

  const handleOrganize = async () => {
    setOrganizing(true);
    try {
      const result = await libraryService.organizeLibrary();
      alert(`Organized ${result.organized} files`);
      await fetchFolders();
    } catch {
      setError("Failed to organize library");
    } finally {
      setOrganizing(false);
    }
  };

  return (
    <div className="mx-auto max-w-5xl px-4 py-6 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          {selectedFolder && (
            <button
              onClick={handleBackToFolders}
              className="rounded-md p-1.5 text-[var(--color-text-muted)] hover:text-[var(--color-text)] hover:bg-[var(--color-surface-hover)] transition-colors"
              title="Back to folders"
            >
              <svg
                className="h-5 w-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M15 19l-7-7 7-7"
                />
              </svg>
            </button>
          )}
          <div>
            <h1 className="text-2xl font-bold text-[var(--color-text)]">
              {selectedFolder ? selectedFolder.name : "Library"}
            </h1>
            {!selectedFolder && (
              <p className="text-sm text-[var(--color-text-muted)]">
                Browse your local video library
              </p>
            )}
          </div>
        </div>

        {!selectedFolder && (
          <button
            onClick={handleOrganize}
            disabled={organizing}
            className="rounded-md bg-[var(--color-surface)] border border-[var(--color-border)] px-4 py-2 text-sm text-[var(--color-text)] hover:bg-[var(--color-surface-hover)] transition-colors disabled:opacity-50"
          >
            {organizing ? "Organizing..." : "Organize Library"}
          </button>
        )}
      </div>

      {error && (
        <div className="mb-4 rounded-lg bg-[var(--color-surface)] border border-[var(--color-danger)] p-3">
          <p className="text-sm text-[var(--color-danger)]">{error}</p>
          <button
            onClick={() => {
              setError(null);
              selectedFolder ? handleFolderClick(selectedFolder) : fetchFolders();
            }}
            className="mt-1 text-xs text-[var(--color-primary)] hover:underline"
          >
            Retry
          </button>
        </div>
      )}

      {/* Video Player */}
      {playingVideo && (
        <div className="mb-6 rounded-lg bg-black overflow-hidden">
          <div className="relative aspect-video">
            <video
              src={libraryService.getDirectStreamUrl(playingVideo.id)}
              controls
              autoPlay
              className="h-full w-full"
            >
              Your browser does not support the video tag.
            </video>
          </div>
          <div className="bg-[var(--color-surface)] px-4 py-2 flex items-center justify-between">
            <p className="text-sm text-[var(--color-text)] truncate">
              {playingVideo.fileName}
            </p>
            <button
              onClick={() => setPlayingVideo(null)}
              className="text-xs text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
            >
              Close
            </button>
          </div>
        </div>
      )}

      {/* Folder Grid */}
      {!selectedFolder && (
        <>
          {loading ? (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
              {[1, 2, 3, 4, 5, 6].map((i) => (
                <div
                  key={i}
                  className="h-32 animate-pulse rounded-lg bg-[var(--color-surface)]"
                />
              ))}
            </div>
          ) : folders.length === 0 ? (
            <div className="rounded-lg bg-[var(--color-surface)] border border-[var(--color-border)] p-12 text-center">
              <svg
                className="mx-auto h-16 w-16 text-[var(--color-text-muted)] mb-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={1}
                  d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
                />
              </svg>
              <p className="text-[var(--color-text-muted)]">
                No library folders found
              </p>
              <p className="text-xs text-[var(--color-text-muted)] mt-1">
                Configure your download settings to populate the library
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
              {folders.map((folder) => (
                <FolderCard
                  key={folder.id}
                  folder={folder}
                  onClick={handleFolderClick}
                />
              ))}
            </div>
          )}
        </>
      )}

      {/* Video List */}
      {selectedFolder && (
        <>
          {videosLoading ? (
            <div className="space-y-3">
              {[1, 2, 3, 4].map((i) => (
                <div
                  key={i}
                  className="h-20 animate-pulse rounded-lg bg-[var(--color-surface)]"
                />
              ))}
            </div>
          ) : videos.length === 0 ? (
            <div className="rounded-lg bg-[var(--color-surface)] border border-[var(--color-border)] p-8 text-center">
              <p className="text-[var(--color-text-muted)]">
                No videos in this folder
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {videos.map((video) => (
                <VideoCard
                  key={video.id}
                  video={video}
                  onPlay={handlePlayVideo}
                />
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/library/page.tsx
git commit -m "feat(web): add library page with folder browser, video list, and direct playback"
```

---

### Task 17: Create Subscription Service

**Files:**
- Create: `web/services/subscription.service.ts`

- [ ] **Step 1: Create `web/services/subscription.service.ts`**

```typescript
import { apiClient } from "@/services/api-client";
import type { CheckoutSession, Subscription } from "@/types/library";
import type { User } from "@/types/user";

class SubscriptionService {
  async createCheckoutSession(priceId?: string): Promise<CheckoutSession> {
    return apiClient.post<CheckoutSession>("/monetization/checkout", {
      priceId,
    });
  }

  async cancelSubscription(): Promise<void> {
    return apiClient.post<void>("/monetization/cancel");
  }

  async getSubscriptionStatus(): Promise<User> {
    return apiClient.get<User>("/users/profile");
  }
}

export const subscriptionService = new SubscriptionService();
```

- [ ] **Step 2: Commit**

```bash
git add web/services/subscription.service.ts
git commit -m "feat(web): add subscription service for Stripe checkout and cancellation"
```

---

### Task 18: Create Subscribe Page

**Files:**
- Create: `web/app/(main)/subscribe/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/subscribe/page.tsx`**

```typescript
"use client";

import { useState, useEffect } from "react";
import { subscriptionService } from "@/services/subscription.service";
import { useAuth } from "@/contexts/AuthContext";
import type { User } from "@/types/user";

const PREMIUM_FEATURES = [
  "Ad-free streaming experience",
  "Download episodes for offline viewing",
  "AI-powered anime recommendations",
  "Priority customer support",
  "Access to premium library content",
  "Higher quality video streams",
];

const FREE_FEATURES = [
  "Browse anime and manga catalog",
  "Stream episodes with ads",
  "Basic search and discovery",
  "Watch history tracking",
  "Community comments and ratings",
];

export default function SubscribePage() {
  const { user: authUser } = useAuth();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [checkoutLoading, setCheckoutLoading] = useState(false);
  const [cancelLoading, setCancelLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchStatus = async () => {
      try {
        const data = await subscriptionService.getSubscriptionStatus();
        setUser(data);
      } catch {
        setError("Failed to load subscription status");
      } finally {
        setLoading(false);
      }
    };
    fetchStatus();
  }, []);

  const handleUpgrade = async () => {
    setCheckoutLoading(true);
    setError(null);
    try {
      const session = await subscriptionService.createCheckoutSession();
      window.location.href = session.sessionUrl;
    } catch {
      setError("Failed to create checkout session. Please try again.");
    } finally {
      setCheckoutLoading(false);
    }
  };

  const handleCancel = async () => {
    const confirmed = window.confirm(
      "Are you sure you want to cancel your premium subscription? You will lose access to premium features at the end of your billing period.",
    );
    if (!confirmed) return;

    setCancelLoading(true);
    setError(null);
    try {
      await subscriptionService.cancelSubscription();
      const updated = await subscriptionService.getSubscriptionStatus();
      setUser(updated);
    } catch {
      setError("Failed to cancel subscription. Please try again.");
    } finally {
      setCancelLoading(false);
    }
  };

  const isPremium = user?.subscriptionTier === "premium";
  const isActive = user?.subscriptionStatus === "active";
  const isCancelled = user?.subscriptionStatus === "cancelled";

  if (loading) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-6 sm:px-6 lg:px-8">
        <div className="animate-pulse space-y-6">
          <div className="h-8 w-48 rounded bg-[var(--color-surface)]" />
          <div className="h-64 rounded-lg bg-[var(--color-surface)]" />
          <div className="h-64 rounded-lg bg-[var(--color-surface)]" />
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 sm:px-6 lg:px-8">
      <h1 className="text-2xl font-bold text-[var(--color-text)] mb-2">
        Subscription
      </h1>
      <p className="text-sm text-[var(--color-text-muted)] mb-8">
        {isPremium
          ? "You are enjoying premium features"
          : "Upgrade to unlock the full SynapseAnime experience"}
      </p>

      {error && (
        <div className="mb-6 rounded-lg bg-[var(--color-surface)] border border-[var(--color-danger)] p-3">
          <p className="text-sm text-[var(--color-danger)]">{error}</p>
        </div>
      )}

      {/* Current Plan Banner */}
      {isPremium && isActive && (
        <div className="mb-8 rounded-lg bg-gradient-to-r from-[var(--color-primary)]/20 to-[var(--color-primary)]/5 border border-[var(--color-primary)]/30 p-6">
          <div className="flex items-center gap-3 mb-2">
            <span className="rounded-full bg-[var(--color-primary)] px-3 py-0.5 text-xs font-bold text-white uppercase">
              Premium
            </span>
            <span className="text-sm text-[var(--color-success)] font-medium">
              Active
            </span>
          </div>
          <p className="text-sm text-[var(--color-text)]">
            Your premium subscription is active.
            {user?.subscriptionExpiresAt && (
              <span className="text-[var(--color-text-muted)]">
                {" "}
                Renews on{" "}
                {new Date(user.subscriptionExpiresAt).toLocaleDateString(
                  "en-US",
                  { year: "numeric", month: "long", day: "numeric" },
                )}
              </span>
            )}
          </p>
        </div>
      )}

      {isPremium && isCancelled && (
        <div className="mb-8 rounded-lg bg-yellow-500/10 border border-yellow-500/30 p-6">
          <div className="flex items-center gap-3 mb-2">
            <span className="rounded-full bg-yellow-500 px-3 py-0.5 text-xs font-bold text-white uppercase">
              Premium
            </span>
            <span className="text-sm text-yellow-400 font-medium">
              Cancelled
            </span>
          </div>
          <p className="text-sm text-[var(--color-text)]">
            Your subscription has been cancelled.
            {user?.subscriptionExpiresAt && (
              <span className="text-[var(--color-text-muted)]">
                {" "}
                You have access until{" "}
                {new Date(user.subscriptionExpiresAt).toLocaleDateString(
                  "en-US",
                  { year: "numeric", month: "long", day: "numeric" },
                )}
              </span>
            )}
          </p>
        </div>
      )}

      {/* Plan Cards */}
      <div className="grid gap-6 md:grid-cols-2">
        {/* Free Plan */}
        <div
          className={`rounded-lg border p-6 ${
            !isPremium
              ? "border-[var(--color-primary)] bg-[var(--color-surface)]"
              : "border-[var(--color-border)] bg-[var(--color-surface)]"
          }`}
        >
          <h2 className="text-lg font-semibold text-[var(--color-text)] mb-1">
            Free
          </h2>
          <p className="text-3xl font-bold text-[var(--color-text)] mb-1">
            $0
            <span className="text-sm font-normal text-[var(--color-text-muted)]">
              /month
            </span>
          </p>
          <p className="text-xs text-[var(--color-text-muted)] mb-4">
            Basic access to SynapseAnime
          </p>

          {!isPremium && (
            <div className="mb-4 rounded-md bg-[var(--color-primary)]/10 px-3 py-1.5 text-center">
              <span className="text-xs font-medium text-[var(--color-primary)]">
                Current Plan
              </span>
            </div>
          )}

          <ul className="space-y-2">
            {FREE_FEATURES.map((feature) => (
              <li
                key={feature}
                className="flex items-start gap-2 text-sm text-[var(--color-text-muted)]"
              >
                <svg
                  className="h-4 w-4 flex-shrink-0 mt-0.5 text-[var(--color-text-muted)]"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M5 13l4 4L19 7"
                  />
                </svg>
                {feature}
              </li>
            ))}
          </ul>
        </div>

        {/* Premium Plan */}
        <div
          className={`rounded-lg border p-6 relative ${
            isPremium
              ? "border-[var(--color-primary)] bg-[var(--color-surface)]"
              : "border-[var(--color-border)] bg-[var(--color-surface)]"
          }`}
        >
          {!isPremium && (
            <div className="absolute -top-3 left-1/2 -translate-x-1/2">
              <span className="rounded-full bg-[var(--color-primary)] px-3 py-0.5 text-xs font-bold text-white">
                RECOMMENDED
              </span>
            </div>
          )}

          <h2 className="text-lg font-semibold text-[var(--color-text)] mb-1">
            Premium
          </h2>
          <p className="text-3xl font-bold text-[var(--color-text)] mb-1">
            $4.99
            <span className="text-sm font-normal text-[var(--color-text-muted)]">
              /month
            </span>
          </p>
          <p className="text-xs text-[var(--color-text-muted)] mb-4">
            Full access to all features
          </p>

          {isPremium && isActive && (
            <div className="mb-4 rounded-md bg-[var(--color-primary)]/10 px-3 py-1.5 text-center">
              <span className="text-xs font-medium text-[var(--color-primary)]">
                Current Plan
              </span>
            </div>
          )}

          {!isPremium && (
            <button
              onClick={handleUpgrade}
              disabled={checkoutLoading}
              className="mb-4 w-full rounded-md bg-[var(--color-primary)] py-2.5 text-sm font-medium text-white hover:bg-[var(--color-primary-hover)] transition-colors disabled:opacity-50"
            >
              {checkoutLoading ? "Redirecting to Stripe..." : "Upgrade to Premium"}
            </button>
          )}

          {isPremium && isActive && (
            <button
              onClick={handleCancel}
              disabled={cancelLoading}
              className="mb-4 w-full rounded-md border border-[var(--color-danger)] py-2.5 text-sm font-medium text-[var(--color-danger)] hover:bg-[var(--color-danger)]/10 transition-colors disabled:opacity-50"
            >
              {cancelLoading ? "Cancelling..." : "Cancel Subscription"}
            </button>
          )}

          {isPremium && isCancelled && (
            <button
              onClick={handleUpgrade}
              disabled={checkoutLoading}
              className="mb-4 w-full rounded-md bg-[var(--color-primary)] py-2.5 text-sm font-medium text-white hover:bg-[var(--color-primary-hover)] transition-colors disabled:opacity-50"
            >
              {checkoutLoading ? "Redirecting to Stripe..." : "Resubscribe"}
            </button>
          )}

          <ul className="space-y-2">
            {PREMIUM_FEATURES.map((feature) => (
              <li
                key={feature}
                className="flex items-start gap-2 text-sm text-[var(--color-text)]"
              >
                <svg
                  className="h-4 w-4 flex-shrink-0 mt-0.5 text-[var(--color-primary)]"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M5 13l4 4L19 7"
                  />
                </svg>
                {feature}
              </li>
            ))}
          </ul>
        </div>
      </div>

      {/* Stripe notice */}
      <p className="mt-8 text-center text-xs text-[var(--color-text-muted)]">
        Payments are processed securely by Stripe. You can cancel anytime.
      </p>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/subscribe/page.tsx
git commit -m "feat(web): add subscribe page with plan comparison and Stripe checkout"
```

---

### Task 19: Update Sidebar/MobileNav with New Routes

**Files:**
- Modify: `web/components/layout/Sidebar.tsx`
- Modify: `web/components/layout/MobileNav.tsx`

- [ ] **Step 1: Add navigation links for downloads, chat, library, and subscribe**

In `web/components/layout/Sidebar.tsx`, add these entries to the navigation items array:

```typescript
{ href: "/downloads", label: "Downloads", icon: /* download arrow icon */ },
{ href: "/chat", label: "AI Chat", icon: /* chat bubble icon */ },
{ href: "/library", label: "Library", icon: /* folder icon */ },
{ href: "/subscribe", label: "Premium", icon: /* star icon */ },
```

In `web/components/layout/MobileNav.tsx`, add the downloads and chat links to the bottom navigation (pick the most important 5 tabs, or add a "More" menu).

- [ ] **Step 2: Commit**

```bash
git add web/components/layout/Sidebar.tsx web/components/layout/MobileNav.tsx
git commit -m "feat(web): add downloads, chat, library, subscribe to navigation"
```

---

### Task 20: Smoke Test

- [ ] **Step 1: Verify build**

```bash
cd web
npm run build
```

Confirm zero TypeScript errors and all pages compile successfully.

- [ ] **Step 2: Verify runtime (manual)**

Start the dev server and check each route:

```bash
cd web
npm run dev
```

| Route | Verify |
|-------|--------|
| `/downloads` | Page loads, tabs switch between Queue/History/Settings, URL download form opens |
| `/chat` | Page loads, suggestion chips render, sending a message shows loading dots |
| `/library` | Page loads, empty state shown when no folders, organize button visible |
| `/subscribe` | Page loads, current plan displayed based on user tier, upgrade/cancel buttons work |

- [ ] **Step 3: Verify WebSocket connection**

1. Open browser DevTools Network tab, filter by WS
2. Log in and confirm two WebSocket connections are established (downloads + history namespaces)
3. Log out and confirm both sockets disconnect

- [ ] **Step 4: Verify Socket.IO reconnection**

1. With sockets connected, temporarily stop the backend
2. Confirm console logs show reconnection attempts
3. Restart the backend and confirm sockets reconnect automatically

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat(web): complete Phase 6 — downloads, AI, library, premium"
```
