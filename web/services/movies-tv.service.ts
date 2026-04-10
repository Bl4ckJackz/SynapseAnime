import { apiClient } from "@/services/api-client";
import type { Movie, TvShow, TvEpisode, CastMember } from "@/types/movies-tv";
import type { PaginatedResult } from "@/types/api";

interface SearchResult {
  id: number;
  title?: string;
  name?: string;
  posterPath?: string;
  voteAverage: number;
  releaseDate?: string;
  firstAirDate?: string;
  mediaType: "movie" | "tv";
}

interface Genre {
  id: number;
  name: string;
}

interface SeasonDetail {
  id: number;
  seasonNumber: number;
  name: string;
  overview?: string;
  posterPath?: string;
  episodes: TvEpisode[];
}

interface StreamUrl {
  url: string;
}

export const moviesTvService = {
  // Movies
  searchMoviesTv(query: string, type?: string, page?: number) {
    return apiClient.get<PaginatedResult<SearchResult>>(
      "/movies-tv/search",
      { q: query, type, page },
    );
  },

  getTrendingMovies(page?: number) {
    return apiClient.get<PaginatedResult<Movie>>(
      "/movies-tv/movies/trending",
      { page },
    );
  },

  getPopularMovies(page?: number) {
    return apiClient.get<PaginatedResult<Movie>>(
      "/movies-tv/movies/popular",
      { page },
    );
  },

  getMovieDetails(id: number) {
    return apiClient.get<Movie>(`/movies-tv/movies/${id}`);
  },

  getMovieStreamUrl(tmdbId: number) {
    return apiClient.get<StreamUrl>(`/movies-tv/stream/movie/${tmdbId}`);
  },

  getMovieGenres() {
    return apiClient.get<Genre[]>("/movies-tv/movies/genres");
  },

  // TV
  getTrendingTvShows(page?: number) {
    return apiClient.get<PaginatedResult<TvShow>>(
      "/movies-tv/tv/trending",
      { page },
    );
  },

  getPopularTvShows(page?: number) {
    return apiClient.get<PaginatedResult<TvShow>>(
      "/movies-tv/tv/popular",
      { page },
    );
  },

  getTvShowDetails(id: number) {
    return apiClient.get<TvShow>(`/movies-tv/tv/${id}`);
  },

  getSeasonDetails(tvId: number, seasonNumber: number) {
    return apiClient.get<SeasonDetail>(
      `/movies-tv/tv/${tvId}/season/${seasonNumber}`,
    );
  },

  getTvStreamUrl(tmdbId: number, season: number, episode: number) {
    return apiClient.get<StreamUrl>(
      `/movies-tv/stream/tv/${tmdbId}/${season}/${episode}`,
    );
  },

  getTvGenres() {
    return apiClient.get<Genre[]>("/movies-tv/tv/genres");
  },
};
