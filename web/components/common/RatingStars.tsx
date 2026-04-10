"use client";

import { cn } from "@/lib/utils";

interface RatingStarsProps {
  rating: number;
  maxRating?: number;
  interactive?: boolean;
  onChange?: (rating: number) => void;
  size?: "sm" | "md" | "lg";
}

export function RatingStars({
  rating,
  maxRating = 5,
  interactive = false,
  onChange,
  size = "md",
}: RatingStarsProps) {
  const sizeClass = { sm: "h-4 w-4", md: "h-5 w-5", lg: "h-6 w-6" }[size];

  return (
    <div className="inline-flex items-center gap-0.5">
      {Array.from({ length: maxRating }, (_, i) => {
        const filled = i < Math.round(rating);
        return (
          <button
            key={i}
            type="button"
            disabled={!interactive}
            onClick={() => interactive && onChange?.(i + 1)}
            className={cn(
              "transition-colors",
              interactive
                ? "cursor-pointer hover:text-yellow-400"
                : "cursor-default",
            )}
          >
            <svg
              className={cn(
                sizeClass,
                filled ? "text-yellow-400" : "text-[var(--color-border)]",
              )}
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
            </svg>
          </button>
        );
      })}
    </div>
  );
}
