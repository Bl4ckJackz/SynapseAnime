"use client";

import { useRef, useState, useEffect, useCallback } from "react";
import Hls from "hls.js";
import { cn } from "@/lib/utils";
import { formatDuration } from "@/lib/utils";

interface VideoPlayerProps {
  src: string;
  onProgress?: (seconds: number) => void;
  initialTime?: number;
}

export function VideoPlayer({ src, onProgress, initialTime }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const hlsRef = useRef<Hls | null>(null);
  const progressTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);
  const [isMuted, setIsMuted] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const hideControlsTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Initialize player
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const isHls = src.includes(".m3u8");

    if (isHls && Hls.isSupported()) {
      const hls = new Hls();
      hlsRef.current = hls;
      hls.loadSource(src);
      hls.attachMedia(video);
      hls.on(Hls.Events.MANIFEST_PARSED, () => {
        if (initialTime && initialTime > 0) {
          video.currentTime = initialTime;
        }
      });
    } else if (isHls && video.canPlayType("application/vnd.apple.mpegurl")) {
      // Native HLS (Safari)
      video.src = src;
      video.addEventListener("loadedmetadata", () => {
        if (initialTime && initialTime > 0) {
          video.currentTime = initialTime;
        }
      }, { once: true });
    } else {
      video.src = src;
      video.addEventListener("loadedmetadata", () => {
        if (initialTime && initialTime > 0) {
          video.currentTime = initialTime;
        }
      }, { once: true });
    }

    return () => {
      if (hlsRef.current) {
        hlsRef.current.destroy();
        hlsRef.current = null;
      }
    };
  }, [src, initialTime]);

  // Progress reporting every 10s
  useEffect(() => {
    if (!onProgress) return;

    progressTimerRef.current = setInterval(() => {
      const video = videoRef.current;
      if (video && !video.paused && video.currentTime > 0) {
        onProgress(Math.floor(video.currentTime));
      }
    }, 10000);

    return () => {
      if (progressTimerRef.current) {
        clearInterval(progressTimerRef.current);
      }
    };
  }, [onProgress]);

  // Video event handlers
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const onTimeUpdate = () => setCurrentTime(video.currentTime);
    const onDurationChange = () => setDuration(video.duration || 0);
    const onPlay = () => setIsPlaying(true);
    const onPause = () => setIsPlaying(false);

    video.addEventListener("timeupdate", onTimeUpdate);
    video.addEventListener("durationchange", onDurationChange);
    video.addEventListener("play", onPlay);
    video.addEventListener("pause", onPause);

    return () => {
      video.removeEventListener("timeupdate", onTimeUpdate);
      video.removeEventListener("durationchange", onDurationChange);
      video.removeEventListener("play", onPlay);
      video.removeEventListener("pause", onPause);
    };
  }, []);

  // Fullscreen change listener
  useEffect(() => {
    const handler = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener("fullscreenchange", handler);
    return () => document.removeEventListener("fullscreenchange", handler);
  }, []);

  const togglePlay = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    if (video.paused) {
      video.play();
    } else {
      video.pause();
    }
  }, []);

  const seek = useCallback((time: number) => {
    const video = videoRef.current;
    if (!video) return;
    video.currentTime = Math.max(0, Math.min(time, video.duration || 0));
  }, []);

  const handleVolumeChange = useCallback((val: number) => {
    const video = videoRef.current;
    if (!video) return;
    video.volume = val;
    setVolume(val);
    setIsMuted(val === 0);
  }, []);

  const toggleMute = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    video.muted = !video.muted;
    setIsMuted(video.muted);
  }, []);

  const toggleFullscreen = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;
    if (!document.fullscreenElement) {
      container.requestFullscreen();
    } else {
      document.exitFullscreen();
    }
  }, []);

  // Keyboard shortcuts
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      // Only handle when no input is focused
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement
      )
        return;

      switch (e.key) {
        case " ":
          e.preventDefault();
          togglePlay();
          break;
        case "ArrowLeft":
          e.preventDefault();
          seek(currentTime - 10);
          break;
        case "ArrowRight":
          e.preventDefault();
          seek(currentTime + 10);
          break;
        case "f":
        case "F":
          e.preventDefault();
          toggleFullscreen();
          break;
      }
    };

    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [togglePlay, seek, toggleFullscreen, currentTime]);

  // Auto-hide controls
  const resetHideTimer = useCallback(() => {
    setShowControls(true);
    if (hideControlsTimer.current) clearTimeout(hideControlsTimer.current);
    hideControlsTimer.current = setTimeout(() => {
      if (videoRef.current && !videoRef.current.paused) {
        setShowControls(false);
      }
    }, 3000);
  }, []);

  const progress = duration > 0 ? (currentTime / duration) * 100 : 0;

  return (
    <div
      ref={containerRef}
      className="group relative aspect-video w-full overflow-hidden rounded-lg bg-black"
      onMouseMove={resetHideTimer}
      onMouseLeave={() => {
        if (isPlaying) setShowControls(false);
      }}
    >
      <video
        ref={videoRef}
        className="h-full w-full cursor-pointer"
        onClick={togglePlay}
        playsInline
      />

      {/* Controls overlay */}
      <div
        className={cn(
          "absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/80 to-transparent px-4 pb-3 pt-10 transition-opacity",
          showControls ? "opacity-100" : "opacity-0",
        )}
      >
        {/* Progress bar */}
        <div
          className="mb-3 h-1 w-full cursor-pointer rounded bg-white/30"
          onClick={(e) => {
            const rect = e.currentTarget.getBoundingClientRect();
            const pct = (e.clientX - rect.left) / rect.width;
            seek(pct * duration);
          }}
        >
          <div
            className="h-full rounded bg-[var(--color-primary)] transition-[width]"
            style={{ width: `${progress}%` }}
          />
        </div>

        <div className="flex items-center gap-3">
          {/* Play/Pause */}
          <button onClick={togglePlay} className="text-white" aria-label={isPlaying ? "Pause" : "Play"}>
            {isPlaying ? (
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <rect x="6" y="4" width="4" height="16" />
                <rect x="14" y="4" width="4" height="16" />
              </svg>
            ) : (
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M8 5v14l11-7z" />
              </svg>
            )}
          </button>

          {/* Time */}
          <span className="text-xs text-white/80">
            {formatDuration(Math.floor(currentTime))} /{" "}
            {formatDuration(Math.floor(duration))}
          </span>

          <div className="flex-1" />

          {/* Volume */}
          <div className="flex items-center gap-1">
            <button onClick={toggleMute} className="text-white" aria-label={isMuted ? "Unmute" : "Mute"}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                {isMuted || volume === 0 ? (
                  <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z" />
                ) : (
                  <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" />
                )}
              </svg>
            </button>
            <input
              type="range"
              min="0"
              max="1"
              step="0.05"
              value={isMuted ? 0 : volume}
              onChange={(e) => handleVolumeChange(Number(e.target.value))}
              className="h-1 w-16 cursor-pointer accent-[var(--color-primary)]"
            />
          </div>

          {/* Fullscreen */}
          <button onClick={toggleFullscreen} className="text-white" aria-label="Toggle fullscreen">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              {isFullscreen ? (
                <path d="M5 16h3v3h2v-5H5v2zm3-8H5v2h5V5H8v3zm6 11h2v-3h3v-2h-5v5zm2-11V5h-2v5h5V8h-3z" />
              ) : (
                <path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z" />
              )}
            </svg>
          </button>
        </div>
      </div>

      {/* Big play button when paused */}
      {!isPlaying && (
        <button
          onClick={togglePlay}
          className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-full bg-black/50 p-4 text-white transition-colors hover:bg-black/70"
          aria-label="Play"
        >
          <svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor">
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>
      )}
    </div>
  );
}
