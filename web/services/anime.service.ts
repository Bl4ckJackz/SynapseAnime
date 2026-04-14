import { apiClient } from "@/services/api-client";
import type { Anime, Episode, AnimeSource } from "@/types/anime";
import type { PaginatedResult } from "@/types/api";

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
function toPaginated<T>(
  input: T[] | PaginatedResult<T> | null | undefined,
  page = 1,
  limit = 0,
): PaginatedResult<T> {
  if (!input) return { data: [], total: 0, page, limit };
  if (Array.isArray(input)) {
    return { data: input, total: input.length, page, limit: limit || input.length };
  }
  return input;
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
    return toPaginated(res, params?.page ?? 1, params?.limit ?? 0);
  }

  async getNewReleases(
    page?: number,
    limit?: number,
  ): Promise<PaginatedResult<Anime>> {
    const res = await apiClient.get<Anime[] | PaginatedResult<Anime>>(
      "/anime/new-releases",
      { page, limit },
    );
    return toPaginated(res, page ?? 1, limit ?? 0);
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
    return toPaginated(res, page ?? 1, limit ?? 0);
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
    return toPaginated(res, page ?? 1, limit ?? 0);
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
    return toPaginated(res, page ?? 1, limit ?? 0);
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
    return toPaginated(res, page ?? 1, limit ?? 0);
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
