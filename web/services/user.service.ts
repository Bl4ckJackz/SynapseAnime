import { apiClient } from "./api-client";
import type { User, UserPreference } from "@/types/user";

export interface WatchHistory {
  id: string;
  userId: string;
  episodeId: string;
  animeId?: string;
  animeTitle?: string;
  animeCover?: string;
  episodeNumber?: number;
  episodeTitle?: string;
  episodeThumbnail?: string;
  progressSeconds: number;
  duration?: number;
  completed?: boolean;
  source?: string;
  watchedAt: string;
}

export interface WatchlistItem {
  id: string;
  userId: string;
  animeId?: string;
  mangaId?: string;
  anime?: { id: string; title: string; coverUrl?: string; rating: number };
  manga?: { id: string; title: string; coverImage?: string; rating: number };
  addedAt: string;
}

export interface ReadingHistory {
  id: string;
  userId: string;
  mangaId: string;
  chapterId: string;
  mangaTitle?: string;
  chapterNumber?: number;
  currentPage?: number;
  totalPages?: number;
  readAt: string;
}

class UserService {
  getProfile(): Promise<User> {
    return apiClient.get<User>("/users/profile");
  }

  updateProfile(data: { nickname?: string }): Promise<User> {
    return apiClient.put<User>("/users/profile", data);
  }

  updatePreferences(
    data: Partial<Pick<UserPreference, "preferredLanguages" | "preferredGenres">>,
  ): Promise<UserPreference> {
    return apiClient.put<UserPreference>("/users/preferences", data);
  }

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

  isAnimeInWatchlist(
    animeId: string,
  ): Promise<{ inWatchlist: boolean }> {
    return apiClient.get<{ inWatchlist: boolean }>(
      `/users/watchlist/${animeId}/check`,
    );
  }

  isMangaInWatchlist(
    mangaId: string,
  ): Promise<{ inWatchlist: boolean }> {
    return apiClient.get<{ inWatchlist: boolean }>(
      `/users/watchlist/manga/${mangaId}/check`,
    );
  }

  getHistory(limit?: number): Promise<WatchHistory[]> {
    return apiClient.get<WatchHistory[]>("/users/history", { limit });
  }

  getContinueWatching(limit?: number): Promise<WatchHistory[]> {
    return apiClient.get<WatchHistory[]>("/users/continue-watching", { limit });
  }

  updateProgress(data: {
    episodeId: string;
    progressSeconds: number;
    animeId?: string;
    animeTitle?: string;
    animeCover?: string;
    animeTotalEpisodes?: number;
    episodeNumber?: number;
    episodeTitle?: string;
    episodeThumbnail?: string;
    duration?: number;
    source?: string;
  }): Promise<WatchHistory> {
    return apiClient.post<WatchHistory>("/users/progress", data);
  }

  getEpisodeProgress(episodeId: string): Promise<WatchHistory | null> {
    return apiClient.get<WatchHistory | null>(
      `/users/progress/${episodeId}`,
    );
  }
}

export const userService = new UserService();
