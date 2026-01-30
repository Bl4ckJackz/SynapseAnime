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
          await this.rateLimiter.acquireToken(this.serviceName);
          // Simplified retry logic compared to generic one for brevity,
          // relying on the robust one already seen in MangaService if strict parity needed.
          // But I'll copy the core logic.

          const response = await operation();
          return response.data;
        } catch (error) {
          const axiosError = error as AxiosError;
          if (axiosError.response && axiosError.response.status === 429) {
            await this.sleep(2000); // Simple backoff for rate limit
            continue;
          }
          throw error;
        }
      }
      throw new Error('Failed to fetch from Jikan API');
    });
  }

  private sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
