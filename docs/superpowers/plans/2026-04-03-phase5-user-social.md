# Phase 5: User Profile & Social — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Profile page with stats, watchlist management (anime + manga), watch/reading history, comment threads with ratings, settings page, notification preferences.

**Architecture:** User-facing pages under the `(main)` route group. Three new services (`user.service.ts`, `comment.service.ts`, `notification.service.ts`) wrap backend REST endpoints via the existing `ApiClient` singleton. `CommentThread` and `RatingStars` are shared components reused on anime detail, manga detail, and any future detail page. All pages are client components (`"use client"`) because they depend on auth state and user interaction.

**Tech Stack:** Next.js 16, React 19, Tailwind CSS v4, TypeScript

**Backend Endpoints Used:**
- `GET /users/profile` — fetch authenticated user profile
- `PUT /users/profile` — update profile (nickname)
- `PUT /users/preferences` — update preferences (languages, genres)
- `GET /users/watchlist` — list watchlist items
- `POST /users/watchlist/:animeId` — add anime to watchlist (path param, not body)
- `DELETE /users/watchlist/:animeId` — remove anime from watchlist
- `GET /users/watchlist/:animeId/check` — check if anime in watchlist
- `POST /users/watchlist/manga/:mangaId` — add manga to watchlist
- `DELETE /users/watchlist/manga/:mangaId` — remove manga from watchlist
- `GET /users/watchlist/manga/:mangaId/check` — check if manga in watchlist
- `GET /users/history?limit=` — watch history
- `GET /users/continue-watching?limit=` — continue watching list
- `POST /users/progress` — update watch progress
- `GET /users/progress/:episodeId` — get episode progress
- `GET /users/anime/:animeId/progress` — get anime-level progress
- `GET /comments/anime/:animeId?page=&limit=` — list anime comments
- `GET /comments/manga/:mangaId?page=&limit=` — list manga comments
- `GET /comments/episode/:episodeId?page=&limit=` — list episode comments
- `GET /comments/:target/:targetId/rating` — get average rating
- `POST /comments` — create comment (body: text, rating?, animeId?, mangaId?, episodeId?, parentId?)
- `PUT /comments/:id` — update comment
- `DELETE /comments/:id` — delete comment
- `GET /notifications/settings` — get notification settings
- `PUT /notifications/settings` — update notification settings

> **NOTE:** No `GET /users/preferences` endpoint exists — preferences are returned embedded in user profile. No `/users/profile/stats` endpoint exists — stats must be computed client-side from history data.

---

## File Structure

```
web/
├── types/
│   └── user.ts                        # ADD: WatchHistory, WatchlistItem, ReadingHistory interfaces
├── services/
│   ├── user.service.ts                # Profile, preferences, watchlist CRUD, history, progress
│   ├── comment.service.ts             # Comment CRUD, ratings
│   └── notification.service.ts        # Notification settings
├── components/
│   └── common/
│       ├── CommentThread.tsx           # Comment list + nested replies + post form + rating
│       └── RatingStars.tsx             # Interactive/display star rating
├── app/
│   └── (main)/
│       ├── profile/page.tsx            # Profile: avatar, stats, quick actions
│       ├── watchlist/page.tsx          # Tabs: anime/manga, grid cards, remove
│       ├── history/page.tsx            # Watch history, progress bars, resume
│       └── settings/page.tsx           # Notifications, preferences, language, source
```

---

### Task 1: Add Missing Type Definitions to `web/types/user.ts`

**Files:**
- Modify: `web/types/user.ts`

- [ ] **Step 1: Append WatchHistory, WatchlistItem, and ReadingHistory interfaces**

Add the following to the end of `web/types/user.ts`:

```typescript
export interface WatchHistory {
  id: string;
  userId: string;
  episodeId: string;
  animeId?: string;
  anime?: {
    id: string;
    title: string;
    coverUrl?: string;
    totalEpisodes: number;
  };
  episode?: {
    id: string;
    number: number;
    title: string;
    duration: number;
  };
  progressSeconds: number;
  completed: boolean;
  watchedAt: string;
  updatedAt: string;
}

export interface WatchlistItem {
  id: string;
  userId: string;
  animeId?: string;
  mangaId?: string;
  anime?: {
    id: string;
    title: string;
    coverUrl?: string;
    rating: number;
    totalEpisodes: number;
    status: string;
  };
  manga?: {
    id: string;
    title: string;
    coverImage?: string;
    rating: number;
    status: string;
  };
  addedAt: string;
}

export interface ReadingHistory {
  id: string;
  userId: string;
  mangaId: string;
  chapterId: string;
  manga?: {
    id: string;
    title: string;
    coverImage?: string;
  };
  chapter?: {
    id: string;
    number: number;
    title?: string;
  };
  progress: number;
  lastReadAt: string;
}

export interface UserStats {
  totalAnimeWatched: number;
  totalEpisodesWatched: number;
  totalMangaRead: number;
  totalChaptersRead: number;
  totalWatchTimeMinutes: number;
  watchlistCount: number;
  commentsCount: number;
}
```

- [ ] **Step 2: Commit**

```bash
git add web/types/user.ts
git commit -m "feat(web): add WatchHistory, WatchlistItem, ReadingHistory, UserStats types"
```

---

### Task 2: Create User Service — `web/services/user.service.ts`

**Files:**
- Create: `web/services/user.service.ts`

- [ ] **Step 1: Create `web/services/user.service.ts`**

```typescript
import { apiClient } from "./api-client";
import type { User, UserPreference, WatchHistory, WatchlistItem, ReadingHistory, UserStats } from "@/types/user";

class UserService {
  // ── Profile ──────────────────────────────────────────────

  getProfile(): Promise<User> {
    return apiClient.get<User>("/users/profile");
  }

  updateProfile(data: { nickname?: string }): Promise<User> {
    return apiClient.put<User>("/users/profile", data);
  }

  // NOTE: No /users/profile/stats endpoint — compute stats client-side from history

  // ── Preferences ──────────────────────────────────────────
  // NOTE: No GET /users/preferences — preferences come embedded in profile response

  updatePreferences(data: Partial<UserPreference>): Promise<UserPreference> {
    return apiClient.put<UserPreference>("/users/preferences", data);
  }

  // ── Watchlist ────────────────────────────────────────────

  getWatchlist(): Promise<WatchlistItem[]> {
    return apiClient.get<WatchlistItem[]>("/users/watchlist");
  }

  addAnimeToWatchlist(animeId: string): Promise<void> {
    return apiClient.post<void>(`/users/watchlist/${animeId}`);
  }

  addMangaToWatchlist(mangaId: string): Promise<void> {
    return apiClient.post<void>(`/users/watchlist/manga/${mangaId}`);
  }

  removeAnimeFromWatchlist(animeId: string): Promise<void> {
    return apiClient.delete<void>(`/users/watchlist/${animeId}`);
  }

  removeMangaFromWatchlist(mangaId: string): Promise<void> {
    return apiClient.delete<void>(`/users/watchlist/manga/${mangaId}`);
  }

  isAnimeInWatchlist(animeId: string): Promise<{ inWatchlist: boolean }> {
    return apiClient.get<{ inWatchlist: boolean }>(`/users/watchlist/${animeId}/check`);
  }

  isMangaInWatchlist(mangaId: string): Promise<{ inWatchlist: boolean }> {
    return apiClient.get<{ inWatchlist: boolean }>(`/users/watchlist/manga/${mangaId}/check`);
  }

  // ── History ──────────────────────────────────────────────

  getHistory(limit?: number): Promise<WatchHistory[]> {
    return apiClient.get<WatchHistory[]>("/users/history", { limit });
  }

  getContinueWatching(limit?: number): Promise<WatchHistory[]> {
    return apiClient.get<WatchHistory[]>("/users/continue-watching", { limit });
  }

  // ── Progress ─────────────────────────────────────────────

  updateProgress(data: {
    episodeId: string;
    animeId: string;
    progressSeconds: number;
    completed?: boolean;
  }): Promise<WatchHistory> {
    return apiClient.post<WatchHistory>("/users/progress", data);
  }

  getEpisodeProgress(episodeId: string): Promise<WatchHistory | null> {
    return apiClient.get<WatchHistory | null>(`/users/progress/${episodeId}`);
  }

  // ── Reading History ──────────────────────────────────────

  getReadingHistory(limit?: number): Promise<ReadingHistory[]> {
    return apiClient.get<ReadingHistory[]>("/users/reading-history", { limit });
  }
}

export const userService = new UserService();
```

- [ ] **Step 2: Commit**

```bash
git add web/services/user.service.ts
git commit -m "feat(web): add user service with profile, watchlist, history, progress"
```

---

### Task 3: Create Comment Service — `web/services/comment.service.ts`

**Files:**
- Create: `web/services/comment.service.ts`

- [ ] **Step 1: Create `web/services/comment.service.ts`**

```typescript
import { apiClient } from "./api-client";
import type { Comment, RatingInfo } from "@/types/comment";
import type { PaginatedResult } from "@/types/api";

export type CommentTarget = "anime" | "manga" | "episode";

class CommentService {
  getComments(
    target: CommentTarget,
    targetId: string,
    page: number = 1,
    limit: number = 20,
  ): Promise<PaginatedResult<Comment>> {
    return apiClient.get<PaginatedResult<Comment>>(
      `/comments/${target}/${targetId}`,
      { page, limit },
    );
  }

  getRating(target: CommentTarget, targetId: string): Promise<RatingInfo> {
    return apiClient.get<RatingInfo>(
      `/comments/${target}/${targetId}/rating`,
    );
  }

  createComment(data: {
    text: string;
    rating?: number;
    animeId?: string;
    mangaId?: string;
    episodeId?: string;
    parentId?: string;
  }): Promise<Comment> {
    return apiClient.post<Comment>("/comments", data);
  }

  updateComment(id: string, data: { text: string; rating?: number }): Promise<Comment> {
    return apiClient.put<Comment>(`/comments/${id}`, data);
  }

  deleteComment(id: string): Promise<void> {
    return apiClient.delete<void>(`/comments/${id}`);
  }
}

export const commentService = new CommentService();
```

- [ ] **Step 2: Commit**

```bash
git add web/services/comment.service.ts
git commit -m "feat(web): add comment service with CRUD and ratings"
```

---

### Task 4: Create Notification Service — `web/services/notification.service.ts`

**Files:**
- Create: `web/services/notification.service.ts`

- [ ] **Step 1: Create `web/services/notification.service.ts`**

```typescript
import { apiClient } from "./api-client";
import type { NotificationSettings } from "@/types/user";

class NotificationService {
  getSettings(): Promise<NotificationSettings> {
    return apiClient.get<NotificationSettings>("/notifications/settings");
  }

  updateSettings(data: Partial<NotificationSettings>): Promise<NotificationSettings> {
    return apiClient.put<NotificationSettings>("/notifications/settings", data);
  }
}

export const notificationService = new NotificationService();
```

- [ ] **Step 2: Commit**

```bash
git add web/services/notification.service.ts
git commit -m "feat(web): add notification service for settings management"
```

---

### Task 5: Create RatingStars Component — `web/components/common/RatingStars.tsx`

**Files:**
- Create: `web/components/common/RatingStars.tsx`

- [ ] **Step 1: Create `web/components/common/RatingStars.tsx`**

```tsx
"use client";

import { useState } from "react";

interface RatingStarsProps {
  value: number;
  onChange?: (rating: number) => void;
  max?: number;
  size?: "sm" | "md" | "lg";
  showValue?: boolean;
  totalRatings?: number;
  readonly?: boolean;
}

const sizeMap = {
  sm: "w-4 h-4",
  md: "w-5 h-5",
  lg: "w-6 h-6",
};

export default function RatingStars({
  value,
  onChange,
  max = 5,
  size = "md",
  showValue = false,
  totalRatings,
  readonly = false,
}: RatingStarsProps) {
  const [hoverValue, setHoverValue] = useState<number>(0);
  const isInteractive = !readonly && !!onChange;
  const displayValue = hoverValue || value;

  return (
    <div className="flex items-center gap-1.5">
      <div className="flex items-center gap-0.5">
        {Array.from({ length: max }, (_, i) => {
          const starIndex = i + 1;
          const isFilled = starIndex <= Math.floor(displayValue);
          const isHalf =
            !isFilled &&
            starIndex === Math.ceil(displayValue) &&
            displayValue % 1 >= 0.25;

          return (
            <button
              key={i}
              type="button"
              disabled={!isInteractive}
              className={`${sizeMap[size]} transition-colors ${
                isInteractive
                  ? "cursor-pointer hover:scale-110"
                  : "cursor-default"
              }`}
              onClick={() => isInteractive && onChange(starIndex)}
              onMouseEnter={() => isInteractive && setHoverValue(starIndex)}
              onMouseLeave={() => isInteractive && setHoverValue(0)}
              aria-label={`Rate ${starIndex} of ${max}`}
            >
              <svg
                viewBox="0 0 24 24"
                fill={isFilled || isHalf ? "currentColor" : "none"}
                stroke="currentColor"
                strokeWidth={1.5}
                className={
                  isFilled
                    ? "text-amber-400"
                    : isHalf
                      ? "text-amber-400"
                      : "text-[var(--color-text-muted)]"
                }
              >
                {isHalf ? (
                  <>
                    <defs>
                      <linearGradient id={`half-${i}`}>
                        <stop offset="50%" stopColor="currentColor" />
                        <stop offset="50%" stopColor="transparent" />
                      </linearGradient>
                    </defs>
                    <path
                      fill={`url(#half-${i})`}
                      d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z"
                    />
                  </>
                ) : (
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z"
                  />
                )}
              </svg>
            </button>
          );
        })}
      </div>
      {showValue && (
        <span className="text-sm text-[var(--color-text-muted)]">
          {value.toFixed(1)}
          {totalRatings !== undefined && (
            <span className="ml-1">({totalRatings})</span>
          )}
        </span>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/common/RatingStars.tsx
git commit -m "feat(web): add RatingStars component with interactive and readonly modes"
```

---

### Task 6: Create CommentThread Component — `web/components/common/CommentThread.tsx`

**Files:**
- Create: `web/components/common/CommentThread.tsx`

- [ ] **Step 1: Create `web/components/common/CommentThread.tsx`**

```tsx
"use client";

import { useState, useEffect, useCallback } from "react";
import { commentService, type CommentTarget } from "@/services/comment.service";
import type { Comment } from "@/types/comment";
import type { RatingInfo } from "@/types/comment";
import RatingStars from "./RatingStars";

interface CommentThreadProps {
  target: CommentTarget;
  targetId: string;
  targetField: "animeId" | "mangaId" | "episodeId";
}

// ── Single Comment ─────────────────────────────────────────

function CommentItem({
  comment,
  targetField,
  targetId,
  onReplyPosted,
  depth,
}: {
  comment: Comment;
  targetField: string;
  targetId: string;
  onReplyPosted: () => void;
  depth: number;
}) {
  const [showReplyForm, setShowReplyForm] = useState(false);
  const [replyText, setReplyText] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleReply = async () => {
    if (!replyText.trim()) return;
    setIsSubmitting(true);
    try {
      await commentService.createComment({
        text: replyText.trim(),
        [targetField]: targetId,
        parentId: comment.id,
      });
      setReplyText("");
      setShowReplyForm(false);
      onReplyPosted();
    } catch (err) {
      console.error("Failed to post reply:", err);
    } finally {
      setIsSubmitting(false);
    }
  };

  const timeAgo = getTimeAgo(comment.createdAt);

  return (
    <div className={`${depth > 0 ? "ml-6 border-l border-[var(--color-border)] pl-4" : ""}`}>
      <div className="py-3">
        {/* Header */}
        <div className="flex items-center gap-2 mb-1">
          <div className="w-7 h-7 rounded-full bg-[var(--color-primary)] flex items-center justify-center text-xs font-bold text-white shrink-0">
            {(comment.user?.nickname || comment.user?.email || "U").charAt(0).toUpperCase()}
          </div>
          <span className="text-sm font-medium text-[var(--color-text)]">
            {comment.user?.nickname || comment.user?.email || "Anonymous"}
          </span>
          <span className="text-xs text-[var(--color-text-muted)]">{timeAgo}</span>
          {comment.rating && comment.rating > 0 && (
            <RatingStars value={comment.rating} size="sm" readonly />
          )}
        </div>

        {/* Body */}
        <p className="text-sm text-[var(--color-text)] leading-relaxed ml-9">
          {comment.text}
        </p>

        {/* Actions */}
        {depth < 3 && (
          <div className="ml-9 mt-1">
            <button
              type="button"
              onClick={() => setShowReplyForm(!showReplyForm)}
              className="text-xs text-[var(--color-primary)] hover:text-[var(--color-primary-hover)] transition-colors"
            >
              Reply
            </button>
          </div>
        )}

        {/* Reply Form */}
        {showReplyForm && (
          <div className="ml-9 mt-2 flex gap-2">
            <input
              type="text"
              value={replyText}
              onChange={(e) => setReplyText(e.target.value)}
              placeholder="Write a reply..."
              className="flex-1 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg px-3 py-1.5 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:border-[var(--color-primary)]"
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  handleReply();
                }
              }}
            />
            <button
              type="button"
              onClick={handleReply}
              disabled={isSubmitting || !replyText.trim()}
              className="px-3 py-1.5 bg-[var(--color-primary)] hover:bg-[var(--color-primary-hover)] text-white text-sm rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSubmitting ? "..." : "Reply"}
            </button>
          </div>
        )}
      </div>

      {/* Nested Replies */}
      {comment.replies && comment.replies.length > 0 && (
        <div>
          {comment.replies.map((reply) => (
            <CommentItem
              key={reply.id}
              comment={reply}
              targetField={targetField}
              targetId={targetId}
              onReplyPosted={onReplyPosted}
              depth={depth + 1}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// ── Time Helper ────────────────────────────────────────────

function getTimeAgo(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diffMs = now - then;
  const diffMin = Math.floor(diffMs / 60000);

  if (diffMin < 1) return "just now";
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHrs = Math.floor(diffMin / 60);
  if (diffHrs < 24) return `${diffHrs}h ago`;
  const diffDays = Math.floor(diffHrs / 24);
  if (diffDays < 30) return `${diffDays}d ago`;
  const diffMonths = Math.floor(diffDays / 30);
  if (diffMonths < 12) return `${diffMonths}mo ago`;
  return `${Math.floor(diffMonths / 12)}y ago`;
}

// ── Main Thread ────────────────────────────────────────────

export default function CommentThread({ target, targetId, targetField }: CommentThreadProps) {
  const [comments, setComments] = useState<Comment[]>([]);
  const [ratingInfo, setRatingInfo] = useState<RatingInfo | null>(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);

  // New comment form state
  const [newText, setNewText] = useState("");
  const [newRating, setNewRating] = useState(0);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchComments = useCallback(async () => {
    setLoading(true);
    try {
      const result = await commentService.getComments(target, targetId, page);
      setComments(result.data);
      setTotalPages(result.totalPages);
    } catch (err) {
      console.error("Failed to fetch comments:", err);
    } finally {
      setLoading(false);
    }
  }, [target, targetId, page]);

  const fetchRating = useCallback(async () => {
    try {
      const info = await commentService.getRating(target, targetId);
      setRatingInfo(info);
    } catch {
      // No rating yet — that is fine
    }
  }, [target, targetId]);

  useEffect(() => {
    fetchComments();
    fetchRating();
  }, [fetchComments, fetchRating]);

  const handlePost = async () => {
    if (!newText.trim()) return;
    setIsSubmitting(true);
    try {
      await commentService.createComment({
        text: newText.trim(),
        rating: newRating > 0 ? newRating : undefined,
        [targetField]: targetId,
      });
      setNewText("");
      setNewRating(0);
      setPage(1);
      fetchComments();
      fetchRating();
    } catch (err) {
      console.error("Failed to post comment:", err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section className="mt-8">
      {/* Header with Rating */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold text-[var(--color-text)]">
          Comments
        </h2>
        {ratingInfo && ratingInfo.totalRatings > 0 && (
          <div className="flex items-center gap-2">
            <RatingStars
              value={ratingInfo.averageRating}
              size="sm"
              readonly
              showValue
              totalRatings={ratingInfo.totalRatings}
            />
          </div>
        )}
      </div>

      {/* Post Form */}
      <div className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl p-4 mb-6">
        <textarea
          value={newText}
          onChange={(e) => setNewText(e.target.value)}
          placeholder="Share your thoughts..."
          rows={3}
          className="w-full bg-transparent text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] resize-none focus:outline-none"
        />
        <div className="flex items-center justify-between mt-3 pt-3 border-t border-[var(--color-border)]">
          <div className="flex items-center gap-2">
            <span className="text-xs text-[var(--color-text-muted)]">Your rating:</span>
            <RatingStars value={newRating} onChange={setNewRating} size="sm" />
          </div>
          <button
            type="button"
            onClick={handlePost}
            disabled={isSubmitting || !newText.trim()}
            className="px-4 py-1.5 bg-[var(--color-primary)] hover:bg-[var(--color-primary-hover)] text-white text-sm font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSubmitting ? "Posting..." : "Post Comment"}
          </button>
        </div>
      </div>

      {/* Comment List */}
      {loading ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="animate-pulse">
              <div className="flex items-center gap-2 mb-2">
                <div className="w-7 h-7 rounded-full bg-[var(--color-surface)]" />
                <div className="h-3 w-24 bg-[var(--color-surface)] rounded" />
              </div>
              <div className="h-3 w-full bg-[var(--color-surface)] rounded ml-9 mb-1" />
              <div className="h-3 w-2/3 bg-[var(--color-surface)] rounded ml-9" />
            </div>
          ))}
        </div>
      ) : comments.length === 0 ? (
        <p className="text-sm text-[var(--color-text-muted)] text-center py-8">
          No comments yet. Be the first to share your thoughts!
        </p>
      ) : (
        <div className="divide-y divide-[var(--color-border)]">
          {comments.map((comment) => (
            <CommentItem
              key={comment.id}
              comment={comment}
              targetField={targetField}
              targetId={targetId}
              onReplyPosted={fetchComments}
              depth={0}
            />
          ))}
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2 mt-6">
          <button
            type="button"
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page === 1}
            className="px-3 py-1.5 text-sm border border-[var(--color-border)] rounded-lg text-[var(--color-text-muted)] hover:bg-[var(--color-surface)] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            Previous
          </button>
          <span className="text-sm text-[var(--color-text-muted)]">
            {page} / {totalPages}
          </span>
          <button
            type="button"
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            disabled={page === totalPages}
            className="px-3 py-1.5 text-sm border border-[var(--color-border)] rounded-lg text-[var(--color-text-muted)] hover:bg-[var(--color-surface)] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            Next
          </button>
        </div>
      )}
    </section>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/components/common/CommentThread.tsx
git commit -m "feat(web): add CommentThread component with nested replies and rating"
```

---

### Task 7: Create Profile Page — `web/app/(main)/profile/page.tsx`

**Files:**
- Create: `web/app/(main)/profile/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/profile/page.tsx`**

```tsx
"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { userService } from "@/services/user.service";
import type { User, UserStats } from "@/types/user";

export default function ProfilePage() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [stats, setStats] = useState<UserStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [nickname, setNickname] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const [profile, userStats] = await Promise.all([
          userService.getProfile(),
          userService.getStats().catch(() => null),
        ]);
        setUser(profile);
        setStats(userStats);
        setNickname(profile.nickname || "");
      } catch (err) {
        console.error("Failed to load profile:", err);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const handleSave = async () => {
    if (!nickname.trim()) return;
    setSaving(true);
    try {
      const updated = await userService.updateProfile({ nickname: nickname.trim() });
      setUser(updated);
      setEditing(false);
    } catch (err) {
      console.error("Failed to update profile:", err);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-8">
        <div className="animate-pulse space-y-6">
          <div className="flex items-center gap-6">
            <div className="w-24 h-24 rounded-full bg-[var(--color-surface)]" />
            <div className="space-y-3 flex-1">
              <div className="h-6 w-48 bg-[var(--color-surface)] rounded" />
              <div className="h-4 w-64 bg-[var(--color-surface)] rounded" />
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-24 bg-[var(--color-surface)] rounded-xl" />
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-8 text-center">
        <p className="text-[var(--color-text-muted)]">Failed to load profile.</p>
      </div>
    );
  }

  const memberSince = new Date(user.createdAt).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
  });

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      {/* Profile Header */}
      <div className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-2xl p-6 mb-6">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6">
          {/* Avatar */}
          <div className="w-24 h-24 rounded-full bg-[var(--color-primary)] flex items-center justify-center text-3xl font-bold text-white shrink-0">
            {user.avatarUrl ? (
              <img
                src={user.avatarUrl}
                alt="Avatar"
                className="w-full h-full rounded-full object-cover"
              />
            ) : (
              (user.nickname || user.email).charAt(0).toUpperCase()
            )}
          </div>

          {/* Info */}
          <div className="flex-1 text-center sm:text-left">
            {editing ? (
              <div className="flex items-center gap-2 mb-2">
                <input
                  type="text"
                  value={nickname}
                  onChange={(e) => setNickname(e.target.value)}
                  className="bg-[var(--color-bg)] border border-[var(--color-border)] rounded-lg px-3 py-1.5 text-lg font-semibold text-[var(--color-text)] focus:outline-none focus:border-[var(--color-primary)]"
                  onKeyDown={(e) => {
                    if (e.key === "Enter") handleSave();
                    if (e.key === "Escape") setEditing(false);
                  }}
                />
                <button
                  type="button"
                  onClick={handleSave}
                  disabled={saving}
                  className="px-3 py-1.5 bg-[var(--color-primary)] text-white text-sm rounded-lg hover:bg-[var(--color-primary-hover)] transition-colors disabled:opacity-50"
                >
                  {saving ? "..." : "Save"}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setEditing(false);
                    setNickname(user.nickname || "");
                  }}
                  className="px-3 py-1.5 border border-[var(--color-border)] text-[var(--color-text-muted)] text-sm rounded-lg hover:bg-[var(--color-surface-hover)] transition-colors"
                >
                  Cancel
                </button>
              </div>
            ) : (
              <div className="flex items-center gap-2 mb-1">
                <h1 className="text-2xl font-bold text-[var(--color-text)]">
                  {user.nickname || user.email.split("@")[0]}
                </h1>
                <button
                  type="button"
                  onClick={() => setEditing(true)}
                  className="text-[var(--color-text-muted)] hover:text-[var(--color-primary)] transition-colors"
                  aria-label="Edit nickname"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z" />
                  </svg>
                </button>
              </div>
            )}
            <p className="text-sm text-[var(--color-text-muted)] mb-1">{user.email}</p>
            <div className="flex items-center gap-3 text-xs text-[var(--color-text-muted)]">
              <span>Member since {memberSince}</span>
              <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                user.subscriptionTier === "premium"
                  ? "bg-amber-500/20 text-amber-400"
                  : "bg-[var(--color-border)] text-[var(--color-text-muted)]"
              }`}>
                {user.subscriptionTier === "premium" ? "Premium" : "Free"}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Stats Grid */}
      {stats && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
          <StatCard label="Anime Watched" value={stats.totalAnimeWatched} icon="tv" />
          <StatCard label="Episodes" value={stats.totalEpisodesWatched} icon="play" />
          <StatCard label="Manga Read" value={stats.totalMangaRead} icon="book" />
          <StatCard label="Watch Time" value={formatWatchTime(stats.totalWatchTimeMinutes)} icon="clock" />
        </div>
      )}

      {/* Quick Actions */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <QuickAction
          title="My Watchlist"
          description="Manage saved anime & manga"
          onClick={() => router.push("/watchlist")}
          icon="bookmark"
        />
        <QuickAction
          title="Watch History"
          description="See what you have watched"
          onClick={() => router.push("/history")}
          icon="history"
        />
        <QuickAction
          title="Settings"
          description="Preferences & notifications"
          onClick={() => router.push("/settings")}
          icon="settings"
        />
        <QuickAction
          title="Downloads"
          description="Manage offline content"
          onClick={() => router.push("/downloads")}
          icon="download"
        />
      </div>
    </div>
  );
}

// ── Sub-components ─────────────────────────────────────────

function StatCard({ label, value, icon }: { label: string; value: string | number; icon: string }) {
  const icons: Record<string, JSX.Element> = {
    tv: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" d="M6 20.25h12m-7.5-3v3m3-3v3m-10.125-3h17.25c.621 0 1.125-.504 1.125-1.125V4.875c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125z" />
      </svg>
    ),
    play: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 010 1.971l-11.54 6.347a1.125 1.125 0 01-1.667-.985V5.653z" />
      </svg>
    ),
    book: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25" />
      </svg>
    ),
    clock: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
  };

  return (
    <div className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl p-4">
      <div className="flex items-center gap-2 mb-2 text-[var(--color-primary)]">
        {icons[icon]}
        <span className="text-xs text-[var(--color-text-muted)]">{label}</span>
      </div>
      <p className="text-2xl font-bold text-[var(--color-text)]">{value}</p>
    </div>
  );
}

function QuickAction({
  title,
  description,
  onClick,
  icon,
}: {
  title: string;
  description: string;
  onClick: () => void;
  icon: string;
}) {
  const icons: Record<string, JSX.Element> = {
    bookmark: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z" />
      </svg>
    ),
    history: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    settings: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" />
        <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
      </svg>
    ),
    download: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
      </svg>
    ),
  };

  return (
    <button
      type="button"
      onClick={onClick}
      className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl p-4 text-left hover:bg-[var(--color-surface-hover)] hover:border-[var(--color-primary)]/30 transition-all group"
    >
      <div className="text-[var(--color-primary)] mb-2 group-hover:scale-110 transition-transform">
        {icons[icon]}
      </div>
      <h3 className="text-sm font-semibold text-[var(--color-text)] mb-0.5">{title}</h3>
      <p className="text-xs text-[var(--color-text-muted)]">{description}</p>
    </button>
  );
}

function formatWatchTime(minutes: number): string {
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  return `${days}d ${hours % 24}h`;
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/profile/page.tsx
git commit -m "feat(web): add profile page with stats grid and quick actions"
```

---

### Task 8: Create Watchlist Page — `web/app/(main)/watchlist/page.tsx`

**Files:**
- Create: `web/app/(main)/watchlist/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/watchlist/page.tsx`**

```tsx
"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { userService } from "@/services/user.service";
import type { WatchlistItem } from "@/types/user";

type Tab = "anime" | "manga";

export default function WatchlistPage() {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>("anime");
  const [items, setItems] = useState<WatchlistItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [removingId, setRemovingId] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const watchlist = await userService.getWatchlist();
        setItems(watchlist);
      } catch (err) {
        console.error("Failed to load watchlist:", err);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const filteredItems = items.filter((item) =>
    tab === "anime" ? item.animeId : item.mangaId,
  );

  const handleRemove = async (itemId: string) => {
    setRemovingId(itemId);
    try {
      await userService.removeFromWatchlist(itemId);
      setItems((prev) => prev.filter((i) => i.id !== itemId));
    } catch (err) {
      console.error("Failed to remove from watchlist:", err);
    } finally {
      setRemovingId(null);
    }
  };

  const handleNavigate = (item: WatchlistItem) => {
    if (item.animeId) router.push(`/anime/${item.animeId}`);
    else if (item.mangaId) router.push(`/manga/${item.mangaId}`);
  };

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      {/* Header */}
      <h1 className="text-2xl font-bold text-[var(--color-text)] mb-6">My Watchlist</h1>

      {/* Tabs */}
      <div className="flex gap-1 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg p-1 w-fit mb-6">
        {(["anime", "manga"] as Tab[]).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTab(t)}
            className={`px-4 py-1.5 text-sm font-medium rounded-md transition-colors ${
              tab === t
                ? "bg-[var(--color-primary)] text-white"
                : "text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
            }`}
          >
            {t === "anime" ? "Anime" : "Manga"}
            <span className="ml-1.5 text-xs opacity-70">
              ({items.filter((i) => (t === "anime" ? i.animeId : i.mangaId)).length})
            </span>
          </button>
        ))}
      </div>

      {/* Grid */}
      {loading ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
          {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => (
            <div key={i} className="animate-pulse">
              <div className="aspect-[3/4] bg-[var(--color-surface)] rounded-xl mb-2" />
              <div className="h-3 w-3/4 bg-[var(--color-surface)] rounded" />
            </div>
          ))}
        </div>
      ) : filteredItems.length === 0 ? (
        <div className="text-center py-16">
          <svg className="w-16 h-16 mx-auto text-[var(--color-text-muted)] mb-4 opacity-40" fill="none" stroke="currentColor" strokeWidth={1} viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z" />
          </svg>
          <p className="text-[var(--color-text-muted)] text-sm">
            Your {tab} watchlist is empty. Start adding {tab === "anime" ? "anime" : "manga"} to keep track!
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
          {filteredItems.map((item) => {
            const title = item.anime?.title || item.manga?.title || "Unknown";
            const cover = item.anime?.coverUrl || item.manga?.coverImage;
            const rating = item.anime?.rating || item.manga?.rating || 0;
            const status = item.anime?.status || item.manga?.status || "";

            return (
              <div key={item.id} className="group relative">
                {/* Card */}
                <button
                  type="button"
                  onClick={() => handleNavigate(item)}
                  className="w-full text-left"
                >
                  <div className="aspect-[3/4] rounded-xl overflow-hidden bg-[var(--color-surface)] border border-[var(--color-border)] mb-2 relative">
                    {cover ? (
                      <img
                        src={cover}
                        alt={title}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-[var(--color-text-muted)] text-xs">
                        No Cover
                      </div>
                    )}
                    {/* Status badge */}
                    {status && (
                      <span className={`absolute top-2 left-2 px-2 py-0.5 rounded text-[10px] font-medium ${
                        status === "ongoing" || status === "ONGOING"
                          ? "bg-green-500/80 text-white"
                          : status === "completed" || status === "COMPLETED"
                            ? "bg-blue-500/80 text-white"
                            : "bg-yellow-500/80 text-white"
                      }`}>
                        {status}
                      </span>
                    )}
                    {/* Rating */}
                    {rating > 0 && (
                      <span className="absolute bottom-2 left-2 bg-black/70 text-amber-400 text-xs px-1.5 py-0.5 rounded flex items-center gap-0.5">
                        <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" />
                        </svg>
                        {rating.toFixed(1)}
                      </span>
                    )}
                  </div>
                  <p className="text-sm font-medium text-[var(--color-text)] line-clamp-2 group-hover:text-[var(--color-primary)] transition-colors">
                    {title}
                  </p>
                </button>

                {/* Remove Button */}
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    handleRemove(item.id);
                  }}
                  disabled={removingId === item.id}
                  className="absolute top-2 right-2 w-7 h-7 bg-black/60 hover:bg-red-600 rounded-full flex items-center justify-center text-white opacity-0 group-hover:opacity-100 transition-all"
                  aria-label="Remove from watchlist"
                >
                  {removingId === item.id ? (
                    <svg className="w-3.5 h-3.5 animate-spin" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                      <circle cx="12" cy="12" r="10" strokeDasharray="32" strokeDashoffset="32" />
                    </svg>
                  ) : (
                    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  )}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/watchlist/page.tsx
git commit -m "feat(web): add watchlist page with anime/manga tabs and remove"
```

---

### Task 9: Create History Page — `web/app/(main)/history/page.tsx`

**Files:**
- Create: `web/app/(main)/history/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/history/page.tsx`**

```tsx
"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { userService } from "@/services/user.service";
import type { WatchHistory } from "@/types/user";

export default function HistoryPage() {
  const router = useRouter();
  const [continueWatching, setContinueWatching] = useState<WatchHistory[]>([]);
  const [history, setHistory] = useState<WatchHistory[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const [cw, hist] = await Promise.all([
          userService.getContinueWatching(10),
          userService.getHistory(50),
        ]);
        setContinueWatching(cw);
        setHistory(hist);
      } catch (err) {
        console.error("Failed to load history:", err);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const handleResume = (item: WatchHistory) => {
    if (item.animeId && item.episodeId) {
      router.push(`/anime/${item.animeId}/player/${item.episodeId}`);
    }
  };

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-8">
        <div className="animate-pulse space-y-4">
          <div className="h-6 w-48 bg-[var(--color-surface)] rounded mb-6" />
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="flex items-center gap-4 p-4 bg-[var(--color-surface)] rounded-xl">
              <div className="w-20 h-14 bg-[var(--color-border)] rounded-lg shrink-0" />
              <div className="flex-1 space-y-2">
                <div className="h-4 w-48 bg-[var(--color-border)] rounded" />
                <div className="h-3 w-32 bg-[var(--color-border)] rounded" />
                <div className="h-2 w-full bg-[var(--color-border)] rounded-full" />
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold text-[var(--color-text)] mb-6">Watch History</h1>

      {/* Continue Watching Section */}
      {continueWatching.length > 0 && (
        <section className="mb-8">
          <h2 className="text-lg font-semibold text-[var(--color-text)] mb-4">Continue Watching</h2>
          <div className="space-y-3">
            {continueWatching.map((item) => (
              <HistoryCard
                key={item.id}
                item={item}
                onResume={() => handleResume(item)}
                showResume
              />
            ))}
          </div>
        </section>
      )}

      {/* Full History */}
      <section>
        <h2 className="text-lg font-semibold text-[var(--color-text)] mb-4">All History</h2>
        {history.length === 0 ? (
          <div className="text-center py-16">
            <svg className="w-16 h-16 mx-auto text-[var(--color-text-muted)] mb-4 opacity-40" fill="none" stroke="currentColor" strokeWidth={1} viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p className="text-[var(--color-text-muted)] text-sm">
              No watch history yet. Start watching anime to track your progress!
            </p>
          </div>
        ) : (
          <div className="space-y-3">
            {history.map((item) => (
              <HistoryCard
                key={item.id}
                item={item}
                onResume={() => handleResume(item)}
                showResume={!item.completed}
              />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

// ── History Card ───────────────────────────────────────────

function HistoryCard({
  item,
  onResume,
  showResume,
}: {
  item: WatchHistory;
  onResume: () => void;
  showResume: boolean;
}) {
  const animeTitle = item.anime?.title || "Unknown Anime";
  const episodeNum = item.episode?.number ?? 0;
  const episodeTitle = item.episode?.title || `Episode ${episodeNum}`;
  const duration = item.episode?.duration || 0;
  const progressPercent = duration > 0 ? Math.min((item.progressSeconds / duration) * 100, 100) : 0;
  const coverUrl = item.anime?.coverUrl;

  const watchedDate = new Date(item.watchedAt).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });

  const formatTime = (seconds: number): string => {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s.toString().padStart(2, "0")}`;
  };

  return (
    <div className="flex items-center gap-4 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl p-4 hover:border-[var(--color-primary)]/30 transition-colors group">
      {/* Thumbnail */}
      <div className="w-20 h-14 rounded-lg overflow-hidden bg-[var(--color-border)] shrink-0 relative">
        {coverUrl ? (
          <img
            src={coverUrl}
            alt={animeTitle}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-[var(--color-text-muted)] text-[10px]">
            No Cover
          </div>
        )}
        {item.completed && (
          <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
            <svg className="w-5 h-5 text-[var(--color-success)]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
          </div>
        )}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-[var(--color-text)] truncate">{animeTitle}</p>
        <p className="text-xs text-[var(--color-text-muted)] truncate">
          Ep {episodeNum} - {episodeTitle}
        </p>
        {/* Progress Bar */}
        <div className="mt-2 flex items-center gap-2">
          <div className="flex-1 h-1.5 bg-[var(--color-border)] rounded-full overflow-hidden">
            <div
              className={`h-full rounded-full transition-all ${
                item.completed ? "bg-[var(--color-success)]" : "bg-[var(--color-primary)]"
              }`}
              style={{ width: `${item.completed ? 100 : progressPercent}%` }}
            />
          </div>
          <span className="text-[10px] text-[var(--color-text-muted)] shrink-0">
            {item.completed ? "Completed" : `${formatTime(item.progressSeconds)} / ${formatTime(duration)}`}
          </span>
        </div>
      </div>

      {/* Date + Resume */}
      <div className="flex flex-col items-end gap-2 shrink-0">
        <span className="text-[10px] text-[var(--color-text-muted)]">{watchedDate}</span>
        {showResume && (
          <button
            type="button"
            onClick={onResume}
            className="px-3 py-1 bg-[var(--color-primary)] hover:bg-[var(--color-primary-hover)] text-white text-xs font-medium rounded-lg transition-colors flex items-center gap-1"
          >
            <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
              <path d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 010 1.971l-11.54 6.347a1.125 1.125 0 01-1.667-.985V5.653z" />
            </svg>
            Resume
          </button>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/history/page.tsx
git commit -m "feat(web): add history page with continue watching and progress bars"
```

---

### Task 10: Create Settings Page — `web/app/(main)/settings/page.tsx`

**Files:**
- Create: `web/app/(main)/settings/page.tsx`

- [ ] **Step 1: Create `web/app/(main)/settings/page.tsx`**

```tsx
"use client";

import { useState, useEffect } from "react";
import { userService } from "@/services/user.service";
import { notificationService } from "@/services/notification.service";
import type { UserPreference, NotificationSettings } from "@/types/user";

const AVAILABLE_LANGUAGES = [
  { code: "en", label: "English" },
  { code: "it", label: "Italiano" },
  { code: "ja", label: "Japanese" },
  { code: "es", label: "Spanish" },
  { code: "fr", label: "French" },
  { code: "de", label: "German" },
  { code: "pt", label: "Portuguese" },
  { code: "ko", label: "Korean" },
  { code: "zh", label: "Chinese" },
];

const AVAILABLE_GENRES = [
  "Action", "Adventure", "Comedy", "Drama", "Fantasy",
  "Horror", "Mecha", "Music", "Mystery", "Psychological",
  "Romance", "Sci-Fi", "Slice of Life", "Sports",
  "Supernatural", "Thriller",
];

const ANIME_SOURCES = [
  { id: "jikan", name: "Jikan (MAL)", description: "MyAnimeList metadata" },
  { id: "hianime", name: "HiAnime", description: "Anime streaming source" },
  { id: "animeunity", name: "AnimeUnity", description: "Italian anime source" },
];

type Section = "preferences" | "notifications" | "sources";

export default function SettingsPage() {
  const [section, setSection] = useState<Section>("preferences");
  const [preferences, setPreferences] = useState<UserPreference | null>(null);
  const [notifSettings, setNotifSettings] = useState<NotificationSettings | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState("");

  // Editable state
  const [selectedLanguages, setSelectedLanguages] = useState<string[]>([]);
  const [selectedGenres, setSelectedGenres] = useState<string[]>([]);
  const [globalNotifications, setGlobalNotifications] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const [prefs, notifs] = await Promise.all([
          userService.getPreferences().catch(() => null),
          notificationService.getSettings().catch(() => null),
        ]);
        if (prefs) {
          setPreferences(prefs);
          setSelectedLanguages(prefs.preferredLanguages || []);
          setSelectedGenres(prefs.preferredGenres || []);
        }
        if (notifs) {
          setNotifSettings(notifs);
          setGlobalNotifications(notifs.globalEnabled);
        }
      } catch (err) {
        console.error("Failed to load settings:", err);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const toggleLanguage = (code: string) => {
    setSelectedLanguages((prev) =>
      prev.includes(code) ? prev.filter((l) => l !== code) : [...prev, code],
    );
  };

  const toggleGenre = (genre: string) => {
    setSelectedGenres((prev) =>
      prev.includes(genre) ? prev.filter((g) => g !== genre) : [...prev, genre],
    );
  };

  const handleSavePreferences = async () => {
    setSaving(true);
    setSaveMessage("");
    try {
      const updated = await userService.updatePreferences({
        preferredLanguages: selectedLanguages,
        preferredGenres: selectedGenres,
      });
      setPreferences(updated);
      setSaveMessage("Preferences saved successfully!");
    } catch (err) {
      console.error("Failed to save preferences:", err);
      setSaveMessage("Failed to save preferences.");
    } finally {
      setSaving(false);
      setTimeout(() => setSaveMessage(""), 3000);
    }
  };

  const handleSaveNotifications = async () => {
    setSaving(true);
    setSaveMessage("");
    try {
      const updated = await notificationService.updateSettings({
        globalEnabled: globalNotifications,
      });
      setNotifSettings(updated);
      setSaveMessage("Notification settings saved!");
    } catch (err) {
      console.error("Failed to save notification settings:", err);
      setSaveMessage("Failed to save notification settings.");
    } finally {
      setSaving(false);
      setTimeout(() => setSaveMessage(""), 3000);
    }
  };

  if (loading) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-8">
        <div className="animate-pulse space-y-6">
          <div className="h-6 w-32 bg-[var(--color-surface)] rounded" />
          <div className="h-10 w-64 bg-[var(--color-surface)] rounded-lg" />
          <div className="h-48 bg-[var(--color-surface)] rounded-xl" />
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold text-[var(--color-text)] mb-6">Settings</h1>

      {/* Section Tabs */}
      <div className="flex gap-1 bg-[var(--color-surface)] border border-[var(--color-border)] rounded-lg p-1 w-fit mb-6">
        {([
          { key: "preferences", label: "Preferences" },
          { key: "notifications", label: "Notifications" },
          { key: "sources", label: "Sources" },
        ] as { key: Section; label: string }[]).map((s) => (
          <button
            key={s.key}
            type="button"
            onClick={() => setSection(s.key)}
            className={`px-4 py-1.5 text-sm font-medium rounded-md transition-colors ${
              section === s.key
                ? "bg-[var(--color-primary)] text-white"
                : "text-[var(--color-text-muted)] hover:text-[var(--color-text)]"
            }`}
          >
            {s.label}
          </button>
        ))}
      </div>

      {/* Save Feedback */}
      {saveMessage && (
        <div className={`mb-4 px-4 py-2 rounded-lg text-sm ${
          saveMessage.includes("Failed")
            ? "bg-red-500/10 text-red-400 border border-red-500/20"
            : "bg-green-500/10 text-green-400 border border-green-500/20"
        }`}>
          {saveMessage}
        </div>
      )}

      {/* ── Preferences Section ──────────────────────────── */}
      {section === "preferences" && (
        <div className="space-y-6">
          {/* Language Selection */}
          <div className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl p-5">
            <h3 className="text-sm font-semibold text-[var(--color-text)] mb-1">Preferred Languages</h3>
            <p className="text-xs text-[var(--color-text-muted)] mb-4">
              Select languages for subtitles and content preferences.
            </p>
            <div className="flex flex-wrap gap-2">
              {AVAILABLE_LANGUAGES.map((lang) => (
                <button
                  key={lang.code}
                  type="button"
                  onClick={() => toggleLanguage(lang.code)}
                  className={`px-3 py-1.5 text-xs font-medium rounded-full border transition-colors ${
                    selectedLanguages.includes(lang.code)
                      ? "bg-[var(--color-primary)] border-[var(--color-primary)] text-white"
                      : "border-[var(--color-border)] text-[var(--color-text-muted)] hover:border-[var(--color-primary)] hover:text-[var(--color-text)]"
                  }`}
                >
                  {lang.label}
                </button>
              ))}
            </div>
          </div>

          {/* Genre Selection */}
          <div className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl p-5">
            <h3 className="text-sm font-semibold text-[var(--color-text)] mb-1">Preferred Genres</h3>
            <p className="text-xs text-[var(--color-text-muted)] mb-4">
              Select your favorite genres for personalized recommendations.
            </p>
            <div className="flex flex-wrap gap-2">
              {AVAILABLE_GENRES.map((genre) => (
                <button
                  key={genre}
                  type="button"
                  onClick={() => toggleGenre(genre)}
                  className={`px-3 py-1.5 text-xs font-medium rounded-full border transition-colors ${
                    selectedGenres.includes(genre)
                      ? "bg-[var(--color-primary)] border-[var(--color-primary)] text-white"
                      : "border-[var(--color-border)] text-[var(--color-text-muted)] hover:border-[var(--color-primary)] hover:text-[var(--color-text)]"
                  }`}
                >
                  {genre}
                </button>
              ))}
            </div>
          </div>

          <button
            type="button"
            onClick={handleSavePreferences}
            disabled={saving}
            className="w-full sm:w-auto px-6 py-2.5 bg-[var(--color-primary)] hover:bg-[var(--color-primary-hover)] text-white text-sm font-medium rounded-lg transition-colors disabled:opacity-50"
          >
            {saving ? "Saving..." : "Save Preferences"}
          </button>
        </div>
      )}

      {/* ── Notifications Section ────────────────────────── */}
      {section === "notifications" && (
        <div className="space-y-6">
          <div className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl p-5">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-sm font-semibold text-[var(--color-text)]">Push Notifications</h3>
                <p className="text-xs text-[var(--color-text-muted)] mt-0.5">
                  Receive notifications for new episodes, releases, and updates.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setGlobalNotifications(!globalNotifications)}
                className={`relative w-11 h-6 rounded-full transition-colors ${
                  globalNotifications ? "bg-[var(--color-primary)]" : "bg-[var(--color-border)]"
                }`}
                role="switch"
                aria-checked={globalNotifications}
              >
                <span
                  className={`absolute top-0.5 w-5 h-5 rounded-full bg-white transition-transform ${
                    globalNotifications ? "left-[22px]" : "left-0.5"
                  }`}
                />
              </button>
            </div>
          </div>

          <div className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl p-5 space-y-4">
            <h3 className="text-sm font-semibold text-[var(--color-text)]">Notification Types</h3>
            {[
              { label: "New Episode Releases", description: "Get notified when new episodes of your watchlist anime air" },
              { label: "Manga Updates", description: "New chapters available for manga in your list" },
              { label: "Recommendations", description: "Personalized anime and manga suggestions" },
            ].map((item, idx) => (
              <div key={idx} className="flex items-start justify-between py-2">
                <div>
                  <p className="text-sm text-[var(--color-text)]">{item.label}</p>
                  <p className="text-xs text-[var(--color-text-muted)]">{item.description}</p>
                </div>
                <div className={`w-9 h-5 rounded-full ${
                  globalNotifications ? "bg-[var(--color-primary)]/30" : "bg-[var(--color-border)]"
                } flex items-center ${globalNotifications ? "justify-end" : "justify-start"} px-0.5`}>
                  <span className={`w-4 h-4 rounded-full ${
                    globalNotifications ? "bg-[var(--color-primary)]" : "bg-[var(--color-text-muted)]"
                  }`} />
                </div>
              </div>
            ))}
          </div>

          <button
            type="button"
            onClick={handleSaveNotifications}
            disabled={saving}
            className="w-full sm:w-auto px-6 py-2.5 bg-[var(--color-primary)] hover:bg-[var(--color-primary-hover)] text-white text-sm font-medium rounded-lg transition-colors disabled:opacity-50"
          >
            {saving ? "Saving..." : "Save Notification Settings"}
          </button>
        </div>
      )}

      {/* ── Sources Section ──────────────────────────────── */}
      {section === "sources" && (
        <div className="space-y-4">
          <p className="text-sm text-[var(--color-text-muted)] mb-2">
            Select the anime streaming source used for episode resolution. The active source determines where stream URLs are fetched from.
          </p>
          {ANIME_SOURCES.map((source) => (
            <div
              key={source.id}
              className="bg-[var(--color-surface)] border border-[var(--color-border)] rounded-xl p-5 flex items-center justify-between hover:border-[var(--color-primary)]/30 transition-colors"
            >
              <div>
                <h3 className="text-sm font-semibold text-[var(--color-text)]">{source.name}</h3>
                <p className="text-xs text-[var(--color-text-muted)] mt-0.5">{source.description}</p>
              </div>
              <span className="text-xs px-2 py-0.5 rounded-full bg-[var(--color-border)] text-[var(--color-text-muted)]">
                Available
              </span>
            </div>
          ))}
          <p className="text-xs text-[var(--color-text-muted)]">
            Source switching is managed per-session. Visit an anime detail page to switch the active source.
          </p>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/settings/page.tsx
git commit -m "feat(web): add settings page with preferences, notifications, sources"
```

---

### Task 11: Integrate CommentThread into Anime Detail Page

**Files:**
- Modify: `web/app/(main)/anime/[id]/page.tsx`

- [ ] **Step 1: Add CommentThread import and render to the anime detail page**

At the top of the file, add:

```typescript
import CommentThread from "@/components/common/CommentThread";
```

At the bottom of the page component's return JSX, before the closing `</div>` of the main container, add:

```tsx
{/* Comments & Ratings */}
<CommentThread target="anime" targetId={params.id} targetField="animeId" />
```

> **Note:** If the anime detail page has not been created by a previous phase, this step should be deferred. The integration point is at the bottom of the anime detail page content, after the episode list and related content sections.

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/anime/\[id\]/page.tsx
git commit -m "feat(web): integrate CommentThread into anime detail page"
```

---

### Task 12: Integrate CommentThread into Manga Detail Page

**Files:**
- Modify: `web/app/(main)/manga/[id]/page.tsx`

- [ ] **Step 1: Add CommentThread import and render to the manga detail page**

At the top of the file, add:

```typescript
import CommentThread from "@/components/common/CommentThread";
```

At the bottom of the page component's return JSX, before the closing `</div>` of the main container, add:

```tsx
{/* Comments & Ratings */}
<CommentThread target="manga" targetId={params.id} targetField="mangaId" />
```

> **Note:** If the manga detail page has not been created by a previous phase, this step should be deferred. The integration point is at the bottom of the manga detail page content, after the chapter list.

- [ ] **Step 2: Commit**

```bash
git add web/app/\(main\)/manga/\[id\]/page.tsx
git commit -m "feat(web): integrate CommentThread into manga detail page"
```

---

### Task 13: Smoke Test

- [ ] **Step 1: Run the TypeScript compiler to verify no type errors**

```bash
cd web
npx tsc --noEmit
```

- [ ] **Step 2: Run the linter**

```bash
cd web
npm run lint
```

- [ ] **Step 3: Start the dev server and verify pages load**

```bash
cd web
npm run dev
```

Manually verify the following routes render without errors:

1. `/profile` — shows profile header with avatar circle, stats grid (may show 0s without backend), and 4 quick action cards
2. `/watchlist` — shows tabs for anime/manga, empty state message when no items
3. `/history` — shows continue watching section (empty) and all history section (empty)
4. `/settings` — shows 3 section tabs (Preferences, Notifications, Sources), language pills, genre pills, toggle switches

- [ ] **Step 4: Verify CommentThread renders on detail pages**

Navigate to any anime or manga detail page (if created in previous phases) and confirm:
- Comment post form appears with textarea and rating stars
- Rating stars are interactive (hover highlights, click selects)
- Empty state shows "No comments yet" message
- Pagination controls do not appear when there is only 1 page

- [ ] **Step 5: Commit any lint/type fixes if needed**

```bash
git add -A
git commit -m "fix(web): resolve lint and type errors from phase 5"
```

---

## Summary

| # | Task | Files | Type |
|---|------|-------|------|
| 1 | Add WatchHistory, WatchlistItem, ReadingHistory, UserStats types | `web/types/user.ts` | Modify |
| 2 | Create user service | `web/services/user.service.ts` | Create |
| 3 | Create comment service | `web/services/comment.service.ts` | Create |
| 4 | Create notification service | `web/services/notification.service.ts` | Create |
| 5 | Create RatingStars component | `web/components/common/RatingStars.tsx` | Create |
| 6 | Create CommentThread component | `web/components/common/CommentThread.tsx` | Create |
| 7 | Create profile page | `web/app/(main)/profile/page.tsx` | Create |
| 8 | Create watchlist page | `web/app/(main)/watchlist/page.tsx` | Create |
| 9 | Create history page | `web/app/(main)/history/page.tsx` | Create |
| 10 | Create settings page | `web/app/(main)/settings/page.tsx` | Create |
| 11 | Integrate CommentThread into anime detail | `web/app/(main)/anime/[id]/page.tsx` | Modify |
| 12 | Integrate CommentThread into manga detail | `web/app/(main)/manga/[id]/page.tsx` | Modify |
| 13 | Smoke test | — | Verify |
