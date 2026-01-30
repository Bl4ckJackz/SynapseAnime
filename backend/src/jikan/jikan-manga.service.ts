import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance, AxiosError } from 'axios';
import { RateLimiterService } from '../common/services/rate-limiter.service';
import { CacheService } from '../common/services/cache.service';
import { CircuitBreakerService } from '../common/services/circuit-breaker.service';
import {
  JikanSearchQueryDto,
  JikanTopMangaQueryDto,
  JikanMangaResponse,
  JikanMangaListResponse,
  JikanCharactersResponse,
  JikanStatisticsResponse,
  JikanRecommendationsResponse,
  MangaDto,
  MangaListDto,
  transformJikanManga,
  transformJikanMangaList,
} from './dto';

@Injectable()
export class JikanMangaService {
  private readonly logger = new Logger(JikanMangaService.name);
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

  async searchManga(query: JikanSearchQueryDto): Promise<MangaListDto> {
    const cacheKey = `jikan:search:${JSON.stringify(query)}`;

    // Check cache first
    const cached = this.cacheService.get<MangaListDto>(cacheKey);
    if (cached) {
      return cached;
    }

    const result = await this.executeWithRetry<JikanMangaListResponse>(
      () => this.client.get('manga', { params: query }),
      cacheKey,
    );

    const transformed = transformJikanMangaList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getMangaById(malId: number): Promise<MangaDto> {
    const cacheKey = `jikan:manga:${malId}`;

    const cached = this.cacheService.get<MangaDto>(cacheKey);
    if (cached) {
      return cached;
    }

    const result = await this.executeWithRetry<JikanMangaResponse>(
      () => this.client.get(`manga/${malId}/full`),
      cacheKey,
    );

    const transformed = transformJikanManga(result.data);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getMangaCharacters(
    malId: number,
  ): Promise<JikanCharactersResponse['data']> {
    const cacheKey = `jikan:manga:${malId}:characters`;

    const cached =
      this.cacheService.get<JikanCharactersResponse['data']>(cacheKey);
    if (cached) {
      return cached;
    }

    const result = await this.executeWithRetry<JikanCharactersResponse>(
      () => this.client.get(`manga/${malId}/characters`),
      cacheKey,
    );

    this.cacheService.set(cacheKey, result.data, this.serviceName);
    return result.data;
  }

  async getMangaStatistics(
    malId: number,
  ): Promise<JikanStatisticsResponse['data']> {
    const cacheKey = `jikan:manga:${malId}:statistics`;

    const cached =
      this.cacheService.get<JikanStatisticsResponse['data']>(cacheKey);
    if (cached) {
      return cached;
    }

    const result = await this.executeWithRetry<JikanStatisticsResponse>(
      () => this.client.get(`manga/${malId}/statistics`),
      cacheKey,
    );

    this.cacheService.set(cacheKey, result.data, this.serviceName);
    return result.data;
  }

  async getTopManga(query: JikanTopMangaQueryDto): Promise<MangaListDto> {
    const cacheKey = `jikan:top:${JSON.stringify(query)}`;

    const cached = this.cacheService.get<MangaListDto>(cacheKey);
    if (cached) {
      return cached;
    }

    const result = await this.executeWithRetry<JikanMangaListResponse>(
      () => this.client.get('top/manga', { params: query }),
      cacheKey,
    );

    const transformed = transformJikanMangaList(result);
    this.cacheService.set(cacheKey, transformed, this.serviceName);
    return transformed;
  }

  async getMangaRecommendations(
    malId: number,
  ): Promise<JikanRecommendationsResponse['data']> {
    const cacheKey = `jikan:manga:${malId}:recommendations`;

    const cached =
      this.cacheService.get<JikanRecommendationsResponse['data']>(cacheKey);
    if (cached) {
      return cached;
    }

    const result = await this.executeWithRetry<JikanRecommendationsResponse>(
      () => this.client.get(`manga/${malId}/recommendations`),
      cacheKey,
    );

    this.cacheService.set(cacheKey, result.data, this.serviceName);
    return result.data;
  }

  async getGenres(): Promise<
    Array<{ mal_id: number; name: string; count: number }>
  > {
    const cacheKey = 'jikan:genres';

    const cached =
      this.cacheService.get<
        Array<{ mal_id: number; name: string; count: number }>
      >(cacheKey);
    if (cached) {
      return cached;
    }

    const result = await this.executeWithRetry<{
      data: Array<{ mal_id: number; name: string; count: number }>;
    }>(() => this.client.get('genres/manga'), cacheKey);

    this.cacheService.set(cacheKey, result.data, this.serviceName);
    return result.data;
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
          const { etag } = this.cacheService.getWithEtag(cacheKey);
          const headers: Record<string, string> = {};
          if (etag) {
            headers['If-None-Match'] = etag;
          }

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
      404: 'Manga not found',
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

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
