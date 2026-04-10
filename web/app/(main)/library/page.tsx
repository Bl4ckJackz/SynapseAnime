"use client";

import { useState, useEffect } from "react";
import {
  libraryService,
  type Folder,
  type LibraryVideo,
} from "@/services/library.service";
import { useToast } from "@/components/ui/Toast";

export default function LibraryPage() {
  const { toast } = useToast();
  const [folders, setFolders] = useState<Folder[]>([]);
  const [selectedFolder, setSelectedFolder] = useState<string | null>(null);
  const [videos, setVideos] = useState<LibraryVideo[]>([]);
  const [playingUrl, setPlayingUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    libraryService
      .getFolders()
      .then(setFolders)
      .catch(() => toast("Failed to load library", "error"))
      .finally(() => setLoading(false));
  }, [toast]);

  async function openFolder(folderId: string) {
    setSelectedFolder(folderId);
    setPlayingUrl(null);
    try {
      const vids = await libraryService.getFolderVideos(folderId);
      setVideos(vids);
    } catch {
      toast("Failed to load folder", "error");
    }
  }

  function playVideo(videoId: string) {
    setPlayingUrl(libraryService.getStreamUrl(videoId));
  }

  return (
    <div className="p-6">
      <h1 className="mb-6 text-2xl font-bold text-[var(--color-text)]">
        Local Library
      </h1>

      {playingUrl && (
        <div className="mb-6">
          <video
            src={playingUrl}
            controls
            autoPlay
            className="w-full rounded-lg bg-black"
            style={{ maxHeight: "60vh" }}
          />
          <button
            onClick={() => setPlayingUrl(null)}
            className="mt-2 text-sm text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
          >
            Close player
          </button>
        </div>
      )}

      {!selectedFolder ? (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
          {loading ? (
            <p className="col-span-full text-sm text-[var(--color-text-muted)]">
              Loading...
            </p>
          ) : folders.length === 0 ? (
            <p className="col-span-full text-center text-sm text-[var(--color-text-muted)]">
              No folders found in library
            </p>
          ) : (
            folders.map((folder) => (
              <button
                key={folder.id}
                onClick={() => openFolder(folder.id)}
                className="flex flex-col items-center gap-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 transition-colors hover:bg-[var(--color-surface-hover)]"
              >
                <svg
                  className="h-10 w-10 text-[var(--color-primary)]"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={1.5}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M5 19a2 2 0 01-2-2V7a2 2 0 012-2h4l2 2h4a2 2 0 012 2v1M5 19h14a2 2 0 002-2v-5a2 2 0 00-2-2H9a2 2 0 00-2 2v5a2 2 0 01-2 2z"
                  />
                </svg>
                <span className="text-sm font-medium text-[var(--color-text)]">
                  {folder.name}
                </span>
                {folder.videoCount !== undefined && (
                  <span className="text-xs text-[var(--color-text-muted)]">
                    {folder.videoCount} videos
                  </span>
                )}
              </button>
            ))
          )}
        </div>
      ) : (
        <div>
          <button
            onClick={() => {
              setSelectedFolder(null);
              setVideos([]);
              setPlayingUrl(null);
            }}
            className="mb-4 text-sm text-[var(--color-primary)] hover:underline"
          >
            Back to folders
          </button>
          <div className="space-y-2">
            {videos.length === 0 ? (
              <p className="text-sm text-[var(--color-text-muted)]">
                No videos in this folder
              </p>
            ) : (
              videos.map((video) => (
                <button
                  key={video.id}
                  onClick={() => playVideo(video.id)}
                  className="flex w-full items-center gap-3 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3 text-left transition-colors hover:bg-[var(--color-surface-hover)]"
                >
                  <svg
                    className="h-8 w-8 shrink-0 text-[var(--color-primary)]"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={1.5}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
                    />
                  </svg>
                  <div>
                    <p className="text-sm font-medium text-[var(--color-text)]">
                      {video.name}
                    </p>
                  </div>
                </button>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}
