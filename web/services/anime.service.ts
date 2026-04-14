import { apiClient } from "@/services/api-client";
import type { Anime, Episode, AnimeSource } from "@/types/anime";
import type { PaginatedResult } from "@/types/api";

type AnimeTitleObject = { default?: string; japanese?: string; romanji?: string; english?: string };

// Different backend sources return `title` either as a string or as a
// localized object ({default, japanese, romanji}). Flatten to a string
// so React components can render it safely.
function normalizeAnime(a: Anime & { title: string | AnimeTitleObject }): Anime {
  if (a && typeof a.title === "object" && a.title !== null) {
    const t = a.title as AnimeTitleObject;
    return {
      ...a,
      title: t.default || t.english || t.romanji || t.japanese || "",
      titleEnglish: a.titleEnglish ?? t.english,
      titleJapanese: a.titleJapanese ?? t.japanese,
    };
  }
  return a as Anime;
}

interface AnimeListParams {
  genre?: string;
  status?: string;
  search?: string;
  page?: number;
  limit?: number;
  sort?: string;
}

// Backend list endpoints may return either a bare array or a paginated
// object depending on the source. Normalize to PaginatedResult for the UI.
function toPaginatedAnime(
  input: Anime[] | PaginatedResult<Anime> | null | undefined,
  page = 1,
  limit = 0,
): PaginatedResult<Anime> {
  if (!input) return { data: [], total: 0, page, limit, totalPages: 0 };
  if (Array.isArray(input)) {
    const normalized = input.map(normalizeAnime);
    const effLimit = limit || normalized.length || 1;
    return {
      data: normalized,
      total: normalized.length,
      page,
      limit: effLimit,
      totalPages: Math.max(1, Math.ceil(normalized.length / effLimit)),
    };
  }
  return { ...input, data: (input.data ?? []).map(normalizeAnime) };
}

class AnimeService {
  async getAnimeList(
    params?: AnimeListParams,
  ): Promise<PaginatedResult<Anime>> {
    const res = await apiClient.get<Anime[] | PaginatedResult<Anime>>("/anime", {
      genre: params?.genre,
      status: params?.status,
      search: params?.search,
      page: params?.page,
      limit: params?.limit,
      sort: params?.sort,
    });
    return toPaginatedAnime(res, params?.page ?? 1, params?.limit ?? 0);
  }

  async getNewReleases(
    page?: number,
    limit?: number,
  ): Promise<PaginatedResult<Anime>> {
    const res = await apiClient.get<Anime[] | PaginatedResult<Anime>>(
      "/anime/new-releases",
      { page, limit },
    );
    return toPaginatedAnime(res, page ?? 1, limit ?? 0);
  }

  async getTopRated(
    page?: number,
    limit?: number,
    filter?: string,
  ): Promise<PaginatedResult<Anime>> {
    const res = await apiClient.get<Anime[] | PaginatedResult<Anime>>(
      "/anime/top-rated",
      { page, limit, filter },
    );
    return toPaginatedAnime(res, page ?? 1, limit ?? 0);
  }

  async getPopular(
    page?: number,
    limit?: number,
  ): Promise<PaginatedResult<Anime>> {
    const res = await apiClient.get<Anime[] | PaginatedResult<Anime>>("/anime", {
      status: "ongoing",
      sort: "popularity",
      page,
      limit,
    });
    return toPaginatedAnime(res, page ?? 1, limit ?? 0);
  }

  async getAiring(
    page?: number,
    limit?: number,
  ): Promise<PaginatedResult<Anime>> {
    const res = await apiClient.get<Anime[] | PaginatedResult<Anime>>("/anime", {
      status: "ongoing",
      page,
      limit,
    });
    return toPaginatedAnime(res, page ?? 1, limit ?? 0);
  }

  async getUpcoming(
    page?: number,
    limit?: number,
  ): Promise<PaginatedResult<Anime>> {
    const res = await apiClient.get<Anime[] | PaginatedResult<Anime>>("/anime", {
      status: "upcoming",
      page,
      limit,
    });
    return toPaginatedAnime(res, page ?? 1, limit ?? 0);
  }

  async getAnimeById(id: string): Promise<Anime> {
    return apiClient.get<Anime>(`/anime/${id}`);
  }

  async getEpisodes(animeId: string): Promise<Episode[]> {
    return apiClient.get<Episode[]>(`/anime/${animeId}/episodes`);
  }

  async getSources(): Promise<AnimeSource[]> {
    return apiClient.get<AnimeSource[]>("/anime/sources");
  }

  async setActiveSource(id: string): Promise<void> {
    return apiClient.post<void>(`/anime/sources/${id}/activate`);
  }

  async getSchedule(day?: string): Promise<Anime[]> {
    return apiClient.get<Anime[]>("/jikan/anime/schedule", { day });
  }

  async getGenres(): Promise<string[]> {
    return apiClient.get<string[]>("/anime/genres");
  }

  async searchAnime(
    q: string,
    page?: number,
    limit?: number,
  ): Promise<PaginatedResult<Anime>> {
    return apiClient.get<PaginatedResult<Anime>>("/jikan/anime/search", {
      q,
      page,
      limit,
    });
  }
}

export const animeService = new AnimeService();
