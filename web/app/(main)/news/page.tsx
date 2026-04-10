"use client";

import { useEffect, useState, useCallback } from "react";
import Image from "next/image";
import Link from "next/link";
import { newsService } from "@/services/news.service";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate, truncate } from "@/lib/utils";
import type { News } from "@/types/news";

const CATEGORIES = [
  "All",
  "Anime",
  "Manga",
  "Industry",
  "Events",
  "Reviews",
  "Releases",
];

export default function NewsPage() {
  const [articles, setArticles] = useState<News[]>([]);
  const [trending, setTrending] = useState<News[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [activeCategory, setActiveCategory] = useState("All");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  const loadNews = useCallback(async () => {
    setLoading(true);
    try {
      const category = activeCategory === "All" ? undefined : activeCategory.toLowerCase();

      if (searchQuery.trim()) {
        const results = await newsService.search(searchQuery, 20);
        setArticles(results);
        setTotalPages(1);
      } else {
        const result = await newsService.getNews(
          undefined,
          category,
          20,
          undefined,
        );
        setArticles(result.data);
        setTotalPages(result.totalPages);
      }
    } catch (err) {
      console.error("Failed to load news:", err);
    } finally {
      setLoading(false);
    }
  }, [activeCategory, searchQuery, page]);

  const loadTrending = useCallback(async () => {
    try {
      const result = await newsService.getTrending(5);
      setTrending(result);
    } catch (err) {
      console.error("Failed to load trending:", err);
    }
  }, []);

  useEffect(() => {
    loadNews();
  }, [loadNews]);

  useEffect(() => {
    loadTrending();
  }, [loadTrending]);

  const handleSearch = () => {
    setPage(1);
    loadNews();
  };

  return (
    <div className="mx-auto max-w-7xl p-4 lg:p-8">
      {/* Search */}
      <div className="mb-6 flex gap-3">
        <div className="flex-1">
          <Input
            placeholder="Search news..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSearch()}
          />
        </div>
        <Button onClick={handleSearch}>Search</Button>
      </div>

      {/* Category Pills */}
      <div className="mb-8 flex flex-wrap gap-2">
        {CATEGORIES.map((cat) => (
          <button
            key={cat}
            onClick={() => {
              setActiveCategory(cat);
              setPage(1);
            }}
            className={`rounded-full px-4 py-1.5 text-sm font-medium transition-colors ${
              activeCategory === cat
                ? "bg-[var(--color-primary)] text-white"
                : "bg-[var(--color-surface)] text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)]"
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      <div className="flex gap-8">
        {/* News Grid */}
        <div className="flex-1">
          {loading ? (
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {Array.from({ length: 6 }).map((_, i) => (
                <div key={i} className="space-y-3">
                  <Skeleton className="aspect-video w-full" />
                  <Skeleton className="h-5 w-3/4" />
                  <Skeleton className="h-4 w-full" />
                  <Skeleton className="h-3 w-1/4" />
                </div>
              ))}
            </div>
          ) : articles.length === 0 ? (
            <p className="py-12 text-center text-[var(--color-text-muted)]">
              No articles found.
            </p>
          ) : (
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {articles.map((article) => (
                <Link
                  key={article.id}
                  href={`/news/${article.id}`}
                  className="group overflow-hidden rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] transition-colors hover:border-[var(--color-primary)]"
                >
                  {/* Cover image */}
                  <div className="relative aspect-video w-full overflow-hidden bg-[var(--color-surface-hover)]">
                    {article.coverImage ? (
                      <Image
                        src={article.coverImage}
                        alt={article.title}
                        fill
                        className="object-cover transition-transform group-hover:scale-105"
                        sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
                      />
                    ) : (
                      <div className="flex h-full w-full items-center justify-center text-[var(--color-text-muted)]">
                        No Image
                      </div>
                    )}
                  </div>

                  <div className="p-4">
                    <h3 className="line-clamp-2 text-sm font-semibold text-[var(--color-text)] group-hover:text-[var(--color-primary)]">
                      {article.title}
                    </h3>
                    <p className="mt-1.5 line-clamp-2 text-xs text-[var(--color-text-muted)]">
                      {truncate(article.excerpt, 120)}
                    </p>
                    <div className="mt-3 flex items-center justify-between">
                      <span className="text-xs text-[var(--color-text-muted)]">
                        {formatDate(article.publishedAt)}
                      </span>
                      <span className="rounded-full bg-[var(--color-surface-hover)] px-2 py-0.5 text-xs font-medium text-[var(--color-text-muted)]">
                        {article.source}
                      </span>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          )}

          {/* Pagination */}
          {!loading && totalPages > 1 && (
            <div className="mt-8 flex items-center justify-center gap-3">
              <Button
                variant="secondary"
                size="sm"
                disabled={page <= 1}
                onClick={() => setPage((p) => p - 1)}
              >
                Previous
              </Button>
              <span className="text-sm text-[var(--color-text-muted)]">
                Page {page} of {totalPages}
              </span>
              <Button
                variant="secondary"
                size="sm"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          )}
        </div>

        {/* Trending Sidebar (desktop only) */}
        <aside className="hidden w-72 flex-shrink-0 lg:block">
          <h3 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
            Trending
          </h3>
          <div className="space-y-4">
            {trending.map((article, index) => (
              <Link
                key={article.id}
                href={`/news/${article.id}`}
                className="group flex gap-3"
              >
                <span className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-[var(--color-primary)] text-sm font-bold text-white">
                  {index + 1}
                </span>
                <div>
                  <p className="line-clamp-2 text-sm font-medium text-[var(--color-text)] group-hover:text-[var(--color-primary)]">
                    {article.title}
                  </p>
                  <span className="text-xs text-[var(--color-text-muted)]">
                    {formatDate(article.publishedAt)}
                  </span>
                </div>
              </Link>
            ))}
          </div>
        </aside>
      </div>
    </div>
  );
}
