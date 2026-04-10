"use client";

import { useState, useEffect } from "react";
import { commentService, type CommentTarget } from "@/services/comment.service";
import { useAuth } from "@/contexts/AuthContext";
import { useToast } from "@/components/ui/Toast";
import { Button } from "@/components/ui/Button";
import { RatingStars } from "./RatingStars";
import { formatDate } from "@/lib/utils";
import type { Comment, RatingInfo } from "@/types/comment";

interface CommentThreadProps {
  target: CommentTarget;
  targetId: string;
}

export function CommentThread({ target, targetId }: CommentThreadProps) {
  const { isAuthenticated, user } = useAuth();
  const { toast } = useToast();
  const [comments, setComments] = useState<Comment[]>([]);
  const [ratingInfo, setRatingInfo] = useState<RatingInfo | null>(null);
  const [text, setText] = useState("");
  const [rating, setRating] = useState(0);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadComments();
    loadRating();
  }, [target, targetId]);

  async function loadComments() {
    try {
      const data = await commentService.getComments(target, targetId);
      setComments(data);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  }

  async function loadRating() {
    try {
      const data = await commentService.getRating(target, targetId);
      setRatingInfo(data);
    } catch {
      // ignore
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!text.trim()) return;
    setSubmitting(true);
    try {
      const targetField =
        target === "anime"
          ? { animeId: targetId }
          : target === "manga"
            ? { mangaId: targetId }
            : { episodeId: targetId };
      const comment = await commentService.createComment({
        text: text.trim(),
        rating: rating > 0 ? rating : undefined,
        ...targetField,
      });
      setComments((prev) => [comment, ...prev]);
      setText("");
      setRating(0);
      loadRating();
      toast("Comment posted!", "success");
    } catch {
      toast("Failed to post comment", "error");
    } finally {
      setSubmitting(false);
    }
  }

  async function handleDelete(id: string) {
    try {
      await commentService.deleteComment(id);
      setComments((prev) => prev.filter((c) => c.id !== id));
      toast("Comment deleted", "info");
    } catch {
      toast("Failed to delete comment", "error");
    }
  }

  return (
    <div className="space-y-6">
      {ratingInfo && (
        <div className="flex items-center gap-3">
          <RatingStars rating={ratingInfo.averageRating} size="lg" />
          <span className="text-sm text-[var(--color-text-muted)]">
            {ratingInfo.averageRating.toFixed(1)} ({ratingInfo.totalRatings}{" "}
            ratings)
          </span>
        </div>
      )}

      {isAuthenticated && (
        <form onSubmit={handleSubmit} className="space-y-3">
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Write a comment..."
            rows={3}
            className="w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]"
          />
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-sm text-[var(--color-text-muted)]">
                Rate:
              </span>
              <RatingStars
                rating={rating}
                interactive
                onChange={setRating}
                size="sm"
              />
            </div>
            <Button type="submit" size="sm" loading={submitting}>
              Post
            </Button>
          </div>
        </form>
      )}

      <div className="space-y-4">
        {loading ? (
          <p className="text-sm text-[var(--color-text-muted)]">
            Loading comments...
          </p>
        ) : comments.length === 0 ? (
          <p className="text-sm text-[var(--color-text-muted)]">
            No comments yet. Be the first!
          </p>
        ) : (
          comments.map((comment) => (
            <div
              key={comment.id}
              className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4"
            >
              <div className="mb-2 flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className="flex h-7 w-7 items-center justify-center rounded-full bg-[var(--color-primary)] text-xs font-medium text-white">
                    {comment.user?.nickname?.[0]?.toUpperCase() || "U"}
                  </div>
                  <span className="text-sm font-medium text-[var(--color-text)]">
                    {comment.user?.nickname || "User"}
                  </span>
                  <span className="text-xs text-[var(--color-text-muted)]">
                    {formatDate(comment.createdAt)}
                  </span>
                </div>
                {comment.userId === user?.id && (
                  <button
                    onClick={() => handleDelete(comment.id)}
                    className="text-xs text-[var(--color-danger)] hover:underline"
                  >
                    Delete
                  </button>
                )}
              </div>
              {comment.rating && (
                <div className="mb-1">
                  <RatingStars rating={comment.rating} size="sm" />
                </div>
              )}
              <p className="text-sm text-[var(--color-text)]">
                {comment.text}
              </p>

              {comment.replies && comment.replies.length > 0 && (
                <div className="mt-3 space-y-2 border-l-2 border-[var(--color-border)] pl-4">
                  {comment.replies.map((reply) => (
                    <div key={reply.id} className="text-sm">
                      <span className="font-medium text-[var(--color-text)]">
                        {reply.user?.nickname || "User"}
                      </span>
                      <span className="ml-2 text-[var(--color-text-muted)]">
                        {reply.text}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  );
}
