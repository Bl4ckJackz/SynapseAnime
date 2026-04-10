import { apiClient } from "@/services/api-client";
import type { News } from "@/types/news";
import type { PaginatedResult } from "@/types/api";

export const newsService = {
  getNews(sources?: string, category?: string, limit?: number, search?: string) {
    return apiClient.get<PaginatedResult<News>>("/news", {
      sources,
      category,
      limit,
      search,
    });
  },

  getRecent(limit?: number) {
    return apiClient.get<News[]>("/news/recent", { limit });
  },

  getTrending(limit?: number) {
    return apiClient.get<News[]>("/news/trending", { limit });
  },

  getByCategory(category: string, limit?: number) {
    return apiClient.get<News[]>(`/news/category/${category}`, { limit });
  },

  search(query: string, limit?: number) {
    return apiClient.get<News[]>(`/news/search/${query}`, { limit });
  },

  getById(id: string) {
    return apiClient.get<News>(`/news/${id}`);
  },
};
