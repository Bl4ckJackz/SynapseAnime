import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance, AxiosError } from 'axios';
import { RateLimiterService } from '../common/services/rate-limiter.service';
import { CacheService } from '../common/services/cache.service';
import { CircuitBreakerService } from '../common/services/circuit-breaker.service';

@Injectable()
export class TmdbService {
  private readonly logger = new Logger(TmdbService.name);
  private readonly client: AxiosInstance;
  private readonly serviceName = 'tmdb';
  private readonly language = 'it-IT';

  constructor(
    private readonly configService: ConfigService,
    private readonly rateLimiter: RateLimiterService,
    private readonly cacheService: CacheService,
    private readonly circuitBreaker: CircuitBreakerService,
  ) {
    const apiKey = this.configService.get<string>('TMDB_API_KEY');
    if (!apiKey) {
      this.logger.warn('TMDB_API_KEY is not set. TMDB requests will fail.');
    }

    this.client = axios.create({
      baseURL: 'https://api.themoviedb.org/3',
      timeout: 10000,
      headers: {
        Accept: 'application/json',
      },
      params: {
        api_key: apiKey,
        language: this.language,
      },
    });
  }

  async searchMulti(query: string, page: number = 1): Promise<any> {
    const cacheKey = `tmdb:search:multi:${query}:${page}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () => this.client.get('/search/multi', { params: { query, page } }),
      cacheKey,
    );

    const transformed = this.transformSearchResults(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async searchMovies(query: string, page: number = 1): Promise<any> {
    const cacheKey = `tmdb:search:movie:${query}:${page}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () => this.client.get('/search/movie', { params: { query, page } }),
      cacheKey,
    );

    const transformed = this.transformMovieList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async searchTvShows(query: string, page: number = 1): Promise<any> {
    const cacheKey = `tmdb:search:tv:${query}:${page}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () => this.client.get('/search/tv', { params: { query, page } }),
      cacheKey,
    );

    const transformed = this.transformTvList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getTrendingMovies(timeWindow: string = 'week', page: number = 1): Promise<any> {
    const cacheKey = `tmdb:trending:movie:${timeWindow}:${page}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () => this.client.get(`/trending/movie/${timeWindow}`, { params: { page } }),
      cacheKey,
    );

    const transformed = this.transformMovieList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getTrendingTvShows(timeWindow: string = 'week', page: number = 1): Promise<any> {
    const cacheKey = `tmdb:trending:tv:${timeWindow}:${page}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () => this.client.get(`/trending/tv/${timeWindow}`, { params: { page } }),
      cacheKey,
    );

    const transformed = this.transformTvList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getMovieDetails(movieId: number): Promise<any> {
    const cacheKey = `tmdb:movie:${movieId}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () =>
        this.client.get(`/movie/${movieId}`, {
          params: { append_to_response: 'credits,videos,similar,recommendations' },
        }),
      cacheKey,
    );

    const transformed = this.transformMovieDetails(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getTvShowDetails(tvId: number): Promise<any> {
    const cacheKey = `tmdb:tv:${tvId}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () =>
        this.client.get(`/tv/${tvId}`, {
          params: { append_to_response: 'credits,videos,similar,recommendations' },
        }),
      cacheKey,
    );

    const transformed = this.transformTvDetails(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getTvSeasonDetails(tvId: number, seasonNumber: number): Promise<any> {
    const cacheKey = `tmdb:tv:${tvId}:season:${seasonNumber}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () => this.client.get(`/tv/${tvId}/season/${seasonNumber}`),
      cacheKey,
    );

    const transformed = this.transformSeasonDetails(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getPopularMovies(page: number = 1): Promise<any> {
    const cacheKey = `tmdb:popular:movie:${page}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () => this.client.get('/movie/popular', { params: { page } }),
      cacheKey,
    );

    const transformed = this.transformMovieList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getPopularTvShows(page: number = 1): Promise<any> {
    const cacheKey = `tmdb:popular:tv:${page}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry(
      () => this.client.get('/tv/popular', { params: { page } }),
      cacheKey,
    );

    const transformed = this.transformTvList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getMovieGenres(): Promise<any> {
    const cacheKey = 'tmdb:genres:movie';

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry<{ genres: { id: number; name: string }[] }>(
      () => this.client.get('/genre/movie/list'),
      cacheKey,
    );

    const genres = result.genres || [];
    this.cacheService.set(cacheKey, genres, this.serviceName);
    return genres;
  }

  async getTvGenres(): Promise<any> {
    const cacheKey = 'tmdb:genres:tv';

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry<{ genres: { id: number; name: string }[] }>(
      () => this.client.get('/genre/tv/list'),
      cacheKey,
    );

    const genres = result.genres || [];
    this.cacheService.set(cacheKey, genres, this.serviceName);
    return genres;
  }

  // --- Transform helpers ---

  private transformSearchResults(response: any) {
    return {
      data: (response.results || []).map((item: any) => {
        if (item.media_type === 'movie') {
          return this.transformMovieItem(item);
        } else if (item.media_type === 'tv') {
          return this.transformTvItem(item);
        }
        return {
          id: item.id,
          mediaType: item.media_type,
          title: item.name || item.title,
          source: 'tmdb',
        };
      }),
      pagination: {
        page: response.page,
        totalPages: response.total_pages,
        totalResults: response.total_results,
        hasNextPage: response.page < response.total_pages,
      },
    };
  }

  private transformMovieList(response: any) {
    return {
      data: (response.results || []).map((movie: any) => this.transformMovieItem(movie)),
      pagination: {
        page: response.page,
        totalPages: response.total_pages,
        totalResults: response.total_results,
        hasNextPage: response.page < response.total_pages,
      },
    };
  }

  private transformTvList(response: any) {
    return {
      data: (response.results || []).map((tv: any) => this.transformTvItem(tv)),
      pagination: {
        page: response.page,
        totalPages: response.total_pages,
        totalResults: response.total_results,
        hasNextPage: response.page < response.total_pages,
      },
    };
  }

  private transformMovieItem(movie: any) {
    return {
      id: movie.id,
      mediaType: 'movie',
      title: movie.title,
      originalTitle: movie.original_title,
      description: movie.overview,
      posterUrl: movie.poster_path
        ? `https://image.tmdb.org/t/p/w500${movie.poster_path}`
        : null,
      backdropUrl: movie.backdrop_path
        ? `https://image.tmdb.org/t/p/w780${movie.backdrop_path}`
        : null,
      releaseDate: movie.release_date,
      releaseYear: movie.release_date
        ? parseInt(movie.release_date.substring(0, 4))
        : null,
      rating: movie.vote_average || 0,
      voteCount: movie.vote_count || 0,
      popularity: movie.popularity || 0,
      genreIds: movie.genre_ids || [],
      originalLanguage: movie.original_language,
      adult: movie.adult || false,
      source: 'tmdb',
    };
  }

  private transformTvItem(tv: any) {
    return {
      id: tv.id,
      mediaType: 'tv',
      title: tv.name,
      originalTitle: tv.original_name,
      description: tv.overview,
      posterUrl: tv.poster_path
        ? `https://image.tmdb.org/t/p/w500${tv.poster_path}`
        : null,
      backdropUrl: tv.backdrop_path
        ? `https://image.tmdb.org/t/p/w780${tv.backdrop_path}`
        : null,
      firstAirDate: tv.first_air_date,
      releaseYear: tv.first_air_date
        ? parseInt(tv.first_air_date.substring(0, 4))
        : null,
      rating: tv.vote_average || 0,
      voteCount: tv.vote_count || 0,
      popularity: tv.popularity || 0,
      genreIds: tv.genre_ids || [],
      originalLanguage: tv.original_language,
      source: 'tmdb',
    };
  }

  private transformMovieDetails(movie: any) {
    return {
      id: movie.id,
      mediaType: 'movie',
      title: movie.title,
      originalTitle: movie.original_title,
      tagline: movie.tagline,
      description: movie.overview,
      posterUrl: movie.poster_path
        ? `https://image.tmdb.org/t/p/w500${movie.poster_path}`
        : null,
      backdropUrl: movie.backdrop_path
        ? `https://image.tmdb.org/t/p/original${movie.backdrop_path}`
        : null,
      releaseDate: movie.release_date,
      releaseYear: movie.release_date
        ? parseInt(movie.release_date.substring(0, 4))
        : null,
      runtime: movie.runtime,
      rating: movie.vote_average || 0,
      voteCount: movie.vote_count || 0,
      popularity: movie.popularity || 0,
      budget: movie.budget,
      revenue: movie.revenue,
      status: movie.status,
      genres: (movie.genres || []).map((g: any) => ({
        id: g.id,
        name: g.name,
      })),
      productionCompanies: (movie.production_companies || []).map((c: any) => ({
        id: c.id,
        name: c.name,
        logoUrl: c.logo_path
          ? `https://image.tmdb.org/t/p/w200${c.logo_path}`
          : null,
      })),
      cast: (movie.credits?.cast || []).slice(0, 20).map((c: any) => ({
        id: c.id,
        name: c.name,
        character: c.character,
        profileUrl: c.profile_path
          ? `https://image.tmdb.org/t/p/w185${c.profile_path}`
          : null,
      })),
      crew: (movie.credits?.crew || [])
        .filter((c: any) => ['Director', 'Writer', 'Screenplay'].includes(c.job))
        .map((c: any) => ({
          id: c.id,
          name: c.name,
          job: c.job,
        })),
      videos: (movie.videos?.results || [])
        .filter((v: any) => v.site === 'YouTube')
        .map((v: any) => ({
          id: v.id,
          key: v.key,
          name: v.name,
          type: v.type,
          site: v.site,
        })),
      similar: (movie.similar?.results || []).slice(0, 10).map((m: any) =>
        this.transformMovieItem(m),
      ),
      recommendations: (movie.recommendations?.results || []).slice(0, 10).map((m: any) =>
        this.transformMovieItem(m),
      ),
      originalLanguage: movie.original_language,
      spokenLanguages: movie.spoken_languages || [],
      adult: movie.adult || false,
      source: 'tmdb',
    };
  }

  private transformTvDetails(tv: any) {
    return {
      id: tv.id,
      mediaType: 'tv',
      title: tv.name,
      originalTitle: tv.original_name,
      tagline: tv.tagline,
      description: tv.overview,
      posterUrl: tv.poster_path
        ? `https://image.tmdb.org/t/p/w500${tv.poster_path}`
        : null,
      backdropUrl: tv.backdrop_path
        ? `https://image.tmdb.org/t/p/original${tv.backdrop_path}`
        : null,
      firstAirDate: tv.first_air_date,
      lastAirDate: tv.last_air_date,
      releaseYear: tv.first_air_date
        ? parseInt(tv.first_air_date.substring(0, 4))
        : null,
      rating: tv.vote_average || 0,
      voteCount: tv.vote_count || 0,
      popularity: tv.popularity || 0,
      status: tv.status,
      type: tv.type,
      numberOfSeasons: tv.number_of_seasons,
      numberOfEpisodes: tv.number_of_episodes,
      episodeRunTime: tv.episode_run_time || [],
      genres: (tv.genres || []).map((g: any) => ({
        id: g.id,
        name: g.name,
      })),
      seasons: (tv.seasons || []).map((s: any) => ({
        id: s.id,
        seasonNumber: s.season_number,
        name: s.name,
        overview: s.overview,
        episodeCount: s.episode_count,
        airDate: s.air_date,
        posterUrl: s.poster_path
          ? `https://image.tmdb.org/t/p/w300${s.poster_path}`
          : null,
      })),
      networks: (tv.networks || []).map((n: any) => ({
        id: n.id,
        name: n.name,
        logoUrl: n.logo_path
          ? `https://image.tmdb.org/t/p/w200${n.logo_path}`
          : null,
      })),
      createdBy: (tv.created_by || []).map((c: any) => ({
        id: c.id,
        name: c.name,
        profileUrl: c.profile_path
          ? `https://image.tmdb.org/t/p/w185${c.profile_path}`
          : null,
      })),
      cast: (tv.credits?.cast || []).slice(0, 20).map((c: any) => ({
        id: c.id,
        name: c.name,
        character: c.character,
        profileUrl: c.profile_path
          ? `https://image.tmdb.org/t/p/w185${c.profile_path}`
          : null,
      })),
      videos: (tv.videos?.results || [])
        .filter((v: any) => v.site === 'YouTube')
        .map((v: any) => ({
          id: v.id,
          key: v.key,
          name: v.name,
          type: v.type,
          site: v.site,
        })),
      similar: (tv.similar?.results || []).slice(0, 10).map((t: any) =>
        this.transformTvItem(t),
      ),
      recommendations: (tv.recommendations?.results || []).slice(0, 10).map((t: any) =>
        this.transformTvItem(t),
      ),
      originalLanguage: tv.original_language,
      source: 'tmdb',
    };
  }

  private transformSeasonDetails(season: any) {
    return {
      id: season.id,
      seasonNumber: season.season_number,
      name: season.name,
      overview: season.overview,
      airDate: season.air_date,
      posterUrl: season.poster_path
        ? `https://image.tmdb.org/t/p/w300${season.poster_path}`
        : null,
      episodes: (season.episodes || []).map((ep: any) => ({
        id: ep.id,
        episodeNumber: ep.episode_number,
        seasonNumber: ep.season_number,
        name: ep.name,
        overview: ep.overview,
        airDate: ep.air_date,
        runtime: ep.runtime,
        stillUrl: ep.still_path
          ? `https://image.tmdb.org/t/p/w300${ep.still_path}`
          : null,
        rating: ep.vote_average || 0,
        voteCount: ep.vote_count || 0,
      })),
      source: 'tmdb',
    };
  }

  // --- Retry and error handling ---

  private async executeWithRetry<T>(
    operation: () => Promise<{ data: T }>,
    cacheKey: string,
    maxRetries: number = 3,
  ): Promise<T> {
    return this.circuitBreaker.execute(this.serviceName, async () => {
      let lastError: Error | null = null;

      for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          await this.rateLimiter.acquireToken(this.serviceName);

          const response = await operation();

          // Store ETag if present
          const responseEtag = (
            response as unknown as { headers?: Record<string, string> }
          ).headers?.['etag'];
          if (responseEtag) {
            this.cacheService.set(
              cacheKey,
              response.data,
              this.serviceName,
              responseEtag,
            );
          }

          return response.data;
        } catch (error) {
          lastError = error as Error;
          const axiosError = error as AxiosError;

          if (axiosError.response) {
            const status = axiosError.response.status;

            // Handle 304 Not Modified
            if (status === 304) {
              const cached = this.cacheService.get<T>(cacheKey);
              if (cached) {
                this.cacheService.updateExpiry(cacheKey, this.serviceName);
                return cached;
              }
            }

            // Don't retry on client errors (except 429)
            if (status >= 400 && status < 500 && status !== 429) {
              throw this.mapError(status, axiosError);
            }

            // Retry on 429 (rate limit) and 5xx errors
            if (status === 429 || status >= 500) {
              const delay = this.calculateBackoff(attempt, status);
              this.logger.warn(
                `TMDB API returned ${status}, retrying in ${delay}ms (attempt ${attempt}/${maxRetries})`,
              );
              await this.sleep(delay);
              continue;
            }
          }

          // Network errors - retry with backoff
          if (attempt < maxRetries) {
            const delay = this.calculateBackoff(attempt, 0);
            this.logger.warn(
              `TMDB API request failed, retrying in ${delay}ms (attempt ${attempt}/${maxRetries})`,
            );
            await this.sleep(delay);
            continue;
          }
        }
      }

      throw lastError || new Error('Failed to fetch from TMDB API');
    });
  }

  private calculateBackoff(attempt: number, statusCode: number): number {
    let delay = Math.min(1000 * Math.pow(2, attempt - 1), 30000);
    delay += Math.random() * 1000;

    if (statusCode === 429) {
      delay = Math.max(delay, 2000);
    }

    return Math.floor(delay);
  }

  private mapError(status: number, error: AxiosError): HttpException {
    const messages: Record<number, string> = {
      400: 'Bad request to TMDB API',
      401: 'Invalid TMDB API key',
      404: 'Resource not found on TMDB',
      422: 'Invalid parameters for TMDB request',
      429: 'TMDB rate limit exceeded, please try again later',
      500: 'TMDB API internal error',
      503: 'TMDB API is temporarily unavailable',
    };

    const message = messages[status] || `TMDB API error: ${status}`;
    const httpStatus =
      status === 429
        ? HttpStatus.TOO_MANY_REQUESTS
        : status === 404
          ? HttpStatus.NOT_FOUND
          : status === 401
            ? HttpStatus.UNAUTHORIZED
            : status >= 500
              ? HttpStatus.SERVICE_UNAVAILABLE
              : HttpStatus.BAD_REQUEST;

    return new HttpException(
      {
        statusCode: httpStatus,
        message,
        error: error.message,
        apiSource: 'tmdb',
      },
      httpStatus,
    );
  }

  private sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
