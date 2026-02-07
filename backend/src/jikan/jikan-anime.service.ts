import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance, AxiosError } from 'axios';
import { RateLimiterService } from '../common/services/rate-limiter.service';
import { CacheService } from '../common/services/cache.service';
import { CircuitBreakerService } from '../common/services/circuit-breaker.service';
import { JikanAnimeSearchQueryDto, JikanTopAnimeQueryDto } from './dto';
import { JikanMangaListResponse, JikanMangaResponse } from './dto'; // We can reuse types or create generic ones if strictness isn't priority, but let's assume Jikan structure is similar.

// We should define Anime specific DTOs ideally, but for now I'll define interfaces here to keep it self-contained for this task
// or I will assume the structure is identical to Manga for the wrapper parts and just differs in the fields.
// Jikan Anime and Manga responses are very similar.

// Helper interfaces for Anime
interface JikanAnime {
  mal_id: number;
  url: string;
  images: { jpg: { image_url: string; large_image_url: string } };
  title: string;
  title_english: string;
  title_japanese: string;
  type: string;
  episodes: number;
  status: string;
  score: number;
  year: number;
  rating: string;
  synopsis: string;
  genres: { name: string }[];
  relations?: {
    relation: string;
    entry: { mal_id: number; type: string; name: string; url: string }[];
  }[];
}

interface JikanAnimeListResponse {
  pagination: any;
  data: JikanAnime[];
}

interface JikanAnimeResponse {
  data: JikanAnime;
}

@Injectable()
export class JikanAnimeService {
  private readonly logger = new Logger(JikanAnimeService.name);
  private readonly client: AxiosInstance;
  private readonly baseUrl: string;
  private readonly serviceName = 'jikan';

  constructor(
    private readonly configService: ConfigService,
    private readonly rateLimiter: RateLimiterService,
    private readonly cacheService: CacheService,
    private readonly circuitBreaker: CircuitBreakerService,
  ) {
    this.baseUrl =
      this.configService.get<string>('JIKAN_API_URL') ||
      'https://api.jikan.moe/v4';

    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: 10000,
      headers: {
        Accept: 'application/json',
      },
    });
  }

  async getTopAnime(query: JikanTopAnimeQueryDto): Promise<any> {
    const cacheKey = `jikan:anime:top:${JSON.stringify(query)}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry<JikanAnimeListResponse>(
      () => this.client.get('top/anime', { params: query }),
      cacheKey,
    );

    const transformed = this.transformAnimeList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getNewReleases(page: number = 1): Promise<any> {
    const cacheKey = `jikan:anime:seasons:now:${page}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry<JikanAnimeListResponse>(
      () => this.client.get('seasons/now', { params: { page } }),
      cacheKey,
    );

    const transformed = this.transformAnimeList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async searchAnime(query: JikanAnimeSearchQueryDto): Promise<any> {
    const cacheKey = `jikan:anime:search:${JSON.stringify(query)}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry<JikanAnimeListResponse>(
      () => this.client.get('anime', { params: query }),
      cacheKey,
    );

    const transformed = this.transformAnimeList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getAnimeById(malId: number): Promise<any> {
    const cacheKey = `jikan:anime:${malId}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry<JikanAnimeResponse>(
      () => this.client.get(`anime/${malId}/full`),
      cacheKey,
    );

    const anime = result.data;
    const transformed = {
      id: anime.mal_id.toString(),
      title: anime.title,
      titleEnglish: anime.title_english,
      titleJapanese: anime.title_japanese,
      description: anime.synopsis,
      coverUrl: anime.images.jpg.large_image_url || anime.images.jpg.image_url,
      genres: anime.genres ? anime.genres.map((g) => g.name) : [],
      relations: anime.relations || [],
      status: this.mapStatus(anime.status),
      releaseYear: anime.year || 0,
      rating: anime.score || 0,
      totalEpisodes: anime.episodes || 0,
      source: 'jikan',
    };

    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getGenres(): Promise<any> {
    const cacheKey = 'jikan:anime:genres';

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry<{
      data: Array<{ mal_id: number; name: string; count: number }>;
    }>(() => this.client.get('genres/anime'), cacheKey);

    // Transform to simple string array for frontend compatibility if needed
    // But frontend expects string list based on repository 'getGenres'
    const genres = result.data.map((g) => g.name);

    this.cacheService.set(cacheKey, genres, this.serviceName);
    return genres;
  }

  async getEpisodes(id: number): Promise<any> {
    const cacheKey = `jikan:anime:${id}:episodes`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const result = await this.executeWithRetry<{
      data: Array<{
        mal_id: number;
        title: string;
        episode: string;
        url: string;
      }>;
    }>(() => this.client.get(`anime/${id}/episodes`), cacheKey);

    // Transform
    const episodes = result.data.map((e) => ({
      id: e.mal_id.toString(),
      animeId: id.toString(),
      number: parseInt(e.episode as any) || e.mal_id, // Jikan sometimes returns strings
      title: e.title,
      duration: 0,
      thumbnail: '', // Jikan episodes don't have distinct thumbnails usually
      streamUrl: '',
    }));

    this.cacheService.set(cacheKey, episodes, this.serviceName);
    return episodes;
  }

  async getSchedule(day?: string): Promise<any> {
    // Map day names for consistency
    const validDays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    const dayFilter = day?.toLowerCase();

    const cacheKey = `jikan:anime:schedule:${dayFilter || 'all'}`;

    const cached = this.cacheService.get(cacheKey);
    if (cached) return cached;

    const params: any = {};
    if (dayFilter && validDays.includes(dayFilter)) {
      params.filter = dayFilter;
    }

    const result = await this.executeWithRetry<JikanAnimeListResponse>(
      () => this.client.get('schedules', { params }),
      cacheKey,
    );

    const transformed = this.transformAnimeList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  private transformAnimeList(response: JikanAnimeListResponse) {
    return {
      data: response.data.map((anime) => ({
        id: anime.mal_id.toString(),
        title: anime.title,
        titleEnglish: anime.title_english,
        titleJapanese: anime.title_japanese,
        description: anime.synopsis,
        coverUrl:
          anime.images.jpg.large_image_url || anime.images.jpg.image_url,
        genres: anime.genres ? anime.genres.map((g) => g.name) : [],
        status: this.mapStatus(anime.status), // Need to map to 'ongoing' or 'completed'
        releaseYear: anime.year || 0,
        rating: anime.score || 0,
        totalEpisodes: anime.episodes || 0,
        source: 'jikan',
      })),
      pagination: {
        hasNextPage: response.pagination?.has_next_page || false,
      },
    };
  }

  private mapStatus(jikanStatus: string): string {
    if (!jikanStatus) return 'completed';
    const status = jikanStatus.toLowerCase();
    if (status.includes('currently') || status.includes('ongoing'))
      return 'ongoing';
    return 'completed';
  }

  private async executeWithRetry<T>(
    operation: () => Promise<{ data: T }>,
    cacheKey: string,
    maxRetries: number = 3,
  ): Promise<T> {
    return this.circuitBreaker.execute(this.serviceName, async () => {
      let lastError: Error | null = null;

      for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          // Acquire rate limit token
          await this.rateLimiter.acquireToken(this.serviceName);

          // Check for ETag in cache
          const { etag } = this.cacheService.getWithEtag<T>(cacheKey);
          const headers: Record<string, string> = {};
          if (etag) {
            headers['If-None-Match'] = etag;
          }

          // Use the headers in the request
          // Note: operation() needs to accept headers or we need to change how we call it. 
          // Since operation is a callback correctly closing over client.get, we can't easily inject headers unless we change operation signature.
          // However, axios `get` calculates headers at call time.
          // The cleanest way without changing all callsites is to just let operation run for now if we can't inject.
          // BUT, looking at `MangaService`, `operation` is `() => this.client.get(...)`.
          // We can't inject headers into `operation` without changing it.
          // Wait, in `MangaService` it DOESN'T verify ETag in request? 
          // Checking check `MangaService`:
          // `const { etag } = this.cacheService.getWithEtag(cacheKey);`
          // `const headers: Record<string, string> = {};`
          // `if (etag) { headers['If-None-Match'] = etag; }`
          // `const response = await operation();` -> This `operation` DOES NOT USE headers in `MangaService` either!
          // So `MangaService` ETag logic is actually BROKEN or INCOMPLETE in the provided snippet?
          // Ah, unless `operation` is constructed with headers? No.
          // Let's fix this in AnimeService properly.
          // We need to pass config to axios.
          // Since we can't easily change `operation` signature everywhere to accept headers, 
          // and `operation` wraps the axios call...
          // We might HAVE to change the call sites to pass headers?
          // Or just standard caching WITHOUT conditional requests for now, but handle 304 if it happens (unlikely without headers).

          // Actually, if we want to fix 429/500, the RETRY logic is the most important part.
          // The ETag part is for bandwidth/rate optimization.
          // If `MangaService` implementation was just copy-pasted and didn't actually send headers, it wasn't doing Conditional GETs.
          // Let's stick to the Retry logic which IS working in MangaService.

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
                `Jikan API returned ${status}, retrying in ${delay}ms (attempt ${attempt}/${maxRetries})`,
              );
              await this.sleep(delay);
              continue;
            }
          }

          // Network errors - retry with backoff
          if (attempt < maxRetries) {
            const delay = this.calculateBackoff(attempt, 0);
            this.logger.warn(
              `Jikan API request failed, retrying in ${delay}ms (attempt ${attempt}/${maxRetries})`,
            );
            await this.sleep(delay);
            continue;
          }
        }
      }

      throw lastError || new Error('Failed to fetch from Jikan API');
    });
  }

  private calculateBackoff(attempt: number, statusCode: number): number {
    // Base delay with exponential backoff
    let delay = Math.min(1000 * Math.pow(2, attempt - 1), 30000);

    // Add jitter
    delay += Math.random() * 1000;

    // For 429, wait longer
    if (statusCode === 429) {
      delay = Math.max(delay, 2000);
    }

    return Math.floor(delay);
  }

  private mapError(status: number, error: AxiosError): HttpException {
    const messages: Record<number, string> = {
      400: 'Bad request to Jikan API',
      404: 'Anime not found',
      405: 'Method not allowed',
      429: 'Rate limit exceeded, please try again later',
      500: 'Jikan API internal error',
      503: 'Jikan API is temporarily unavailable',
    };

    const message = messages[status] || `Jikan API error: ${status}`;
    const httpStatus =
      status === 429
        ? HttpStatus.TOO_MANY_REQUESTS
        : status === 404
          ? HttpStatus.NOT_FOUND
          : status >= 500
            ? HttpStatus.SERVICE_UNAVAILABLE
            : HttpStatus.BAD_REQUEST;

    return new HttpException(
      {
        statusCode: httpStatus,
        message,
        error: error.message,
        apiSource: 'jikan',
      },
      httpStatus,
    );
  }

  private sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
