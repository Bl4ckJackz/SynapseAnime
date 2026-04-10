import { apiClient } from "@/services/api-client";
import type { Manga, Chapter } from "@/types/manga";
import type { PaginatedResult } from "@/types/api";

class MangaService {
  // ── Jikan endpoints ──

  async searchJikan(
    q: string,
    page?: number,
  ): Promise<PaginatedResult<Manga>> {
    return apiClient.get<PaginatedResult<Manga>>("/jikan/manga/search", {
      q,
      page,
    });
  }

  async getTopManga(page?: number): Promise<PaginatedResult<Manga>> {
    return apiClient.get<PaginatedResult<Manga>>("/jikan/manga/top", { page });
  }

  async getJikanMangaById(malId: number): Promise<Manga> {
    return apiClient.get<Manga>(`/jikan/manga/${malId}`);
  }

  async getMangaGenres(): Promise<string[]> {
    return apiClient.get<string[]>("/jikan/manga/genres");
  }

  // ── MangaDex endpoints ──

  async searchMangadex(q: string): Promise<{ data: Manga[] }> {
    return apiClient.get<{ data: Manga[] }>("/mangadex/manga/search", { q });
  }

  async getMangaDetails(id: string): Promise<Manga> {
    return apiClient.get<Manga>(`/mangadex/manga/${id}`);
  }

  async getChapters(mangaId: string, lang?: string): Promise<Chapter[]> {
    return apiClient.get<Chapter[]>(`/mangadex/manga/${mangaId}/chapters`, {
      lang,
    });
  }

  async getChapterPages(
    chapterId: string,
  ): Promise<{ images: string[] }> {
    return apiClient.get<{ images: string[] }>(
      `/mangadex/chapter/${chapterId}/pages`,
    );
  }

  // ── MangaHook endpoints ──

  async getMangaHookList(
    page?: number,
    type?: string,
    category?: string,
  ): Promise<PaginatedResult<Manga>> {
    return apiClient.get<PaginatedResult<Manga>>("/mangahook/manga", {
      page,
      type,
      category,
    });
  }

  async searchMangaHook(
    q: string,
    page?: number,
  ): Promise<PaginatedResult<Manga>> {
    return apiClient.get<PaginatedResult<Manga>>("/mangahook/manga/search", {
      q,
      page,
    });
  }

  async getMangaHookDetail(id: string): Promise<Manga> {
    return apiClient.get<Manga>(`/mangahook/manga/${id}`);
  }

  async getMangaHookChapter(
    mangaId: string,
    chapterId: string,
  ): Promise<{ images: string[] }> {
    return apiClient.get<{ images: string[] }>(
      `/mangahook/manga/${mangaId}/chapter/${chapterId}`,
    );
  }
}

export const mangaService = new MangaService();
