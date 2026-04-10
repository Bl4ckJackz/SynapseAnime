"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { newsService } from "@/services/news.service";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate } from "@/lib/utils";
import type { News } from "@/types/news";

export default function NewsDetailPage() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;

  const [article, setArticle] = useState<News | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    newsService
      .getById(id)
      .then(setArticle)
      .catch((err) => console.error("Failed to load article:", err))
      .finally(() => setLoading(false));
  }, [id]);

  if (loading) {
    return (
      <div className="mx-auto max-w-3xl space-y-6 p-4 lg:p-8">
        <Skeleton className="aspect-video w-full" />
        <Skeleton className="h-8 w-3/4" />
        <Skeleton className="h-4 w-1/4" />
        <Skeleton className="h-4 w-full" />
        <Skeleton className="h-4 w-full" />
        <Skeleton className="h-4 w-2/3" />
      </div>
    );
  }

  if (!article) {
    return (
      <div className="flex h-96 items-center justify-center">
        <p className="text-[var(--color-text-muted)]">Article not found.</p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl p-4 lg:p-8">
      {/* Back button */}
      <Button
        variant="ghost"
        size="sm"
        onClick={() => router.back()}
        className="mb-6"
      >
        <svg
          className="mr-1.5 h-4 w-4"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M15 19l-7-7 7-7"
          />
        </svg>
        Back
      </Button>

      {/* Cover image */}
      {article.coverImage && (
        <div className="relative mb-6 aspect-video w-full overflow-hidden rounded-lg">
          <Image
            src={article.coverImage}
            alt={article.title}
            fill
            className="object-cover"
            priority
          />
        </div>
      )}

      {/* Title */}
      <h1 className="mb-4 text-2xl font-bold text-[var(--color-text)] lg:text-3xl">
        {article.title}
      </h1>

      {/* Meta */}
      <div className="mb-6 flex flex-wrap items-center gap-3 text-sm text-[var(--color-text-muted)]">
        <span>{formatDate(article.publishedAt)}</span>
        <span className="rounded-full bg-[var(--color-surface)] px-2.5 py-0.5 text-xs font-medium">
          {article.source}
        </span>
        <span className="rounded-full bg-[var(--color-surface)] px-2.5 py-0.5 text-xs font-medium">
          {article.category}
        </span>
      </div>

      {/* Content */}
      <article
        className="prose prose-invert max-w-none text-[var(--color-text-muted)] prose-headings:text-[var(--color-text)] prose-a:text-[var(--color-primary)] prose-strong:text-[var(--color-text)]"
        dangerouslySetInnerHTML={{ __html: article.content }}
      />

      {/* Tags */}
      {article.tags && article.tags.length > 0 && (
        <div className="mt-8 flex flex-wrap gap-2">
          {article.tags.map((tag) => (
            <span
              key={tag}
              className="rounded-full border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-1 text-xs text-[var(--color-text-muted)]"
            >
              #{tag}
            </span>
          ))}
        </div>
      )}

      {/* External link */}
      {article.externalUrl && (
        <div className="mt-6">
          <a
            href={article.externalUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-sm text-[var(--color-primary)] hover:underline"
          >
            Read original article
            <svg
              className="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
              />
            </svg>
          </a>
        </div>
      )}
    </div>
  );
}
