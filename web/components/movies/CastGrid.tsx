"use client";

import Image from "next/image";
import { cn } from "@/lib/utils";
import type { CastMember } from "@/types/movies-tv";

interface CastGridProps {
  cast: CastMember[];
  className?: string;
}

export function CastGrid({ cast, className }: CastGridProps) {
  if (!cast || cast.length === 0) return null;

  return (
    <div className={cn("w-full", className)}>
      <h3 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
        Cast
      </h3>
      <div className="flex gap-4 overflow-x-auto pb-4 scrollbar-thin scrollbar-track-transparent scrollbar-thumb-[var(--color-border)]">
        {cast.map((member, index) => (
          <div
            key={`${member.name}-${index}`}
            className="flex w-24 flex-shrink-0 flex-col items-center gap-2 text-center"
          >
            <div className="relative h-20 w-20 overflow-hidden rounded-full bg-[var(--color-surface-hover)]">
              {member.profilePath ? (
                <Image
                  src={`https://image.tmdb.org/t/p/w185${member.profilePath}`}
                  alt={member.name}
                  fill
                  className="object-cover"
                  sizes="80px"
                />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-2xl text-[var(--color-text-muted)]">
                  {member.name.charAt(0)}
                </div>
              )}
            </div>
            <div className="w-full">
              <p className="line-clamp-1 text-xs font-medium text-[var(--color-text)]">
                {member.name}
              </p>
              {member.character && (
                <p className="line-clamp-1 text-xs text-[var(--color-text-muted)]">
                  {member.character}
                </p>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
