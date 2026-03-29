import { Injectable, Logger } from '@nestjs/common';
import { TmdbService } from './tmdb.service';
import { VidsrcSource } from './vidsrc.source';
import { MoviesTvSearchDto, MediaType } from './dto/movies-tv-search.dto';

@Injectable()
export class MoviesTvService {
  private readonly logger = new Logger(MoviesTvService.name);

  constructor(
    private readonly tmdbService: TmdbService,
    private readonly vidsrcSource: VidsrcSource,
  ) {}

  async search(dto: MoviesTvSearchDto): Promise<any> {
    this.logger.debug(`Searching for "${dto.q}" with type=${dto.type || 'multi'}`);

    if (dto.type === MediaType.MOVIE) {
      return this.tmdbService.searchMovies(dto.q, dto.page);
    } else if (dto.type === MediaType.TV) {
      return this.tmdbService.searchTvShows(dto.q, dto.page);
    }

    return this.tmdbService.searchMulti(dto.q, dto.page);
  }

  async getTrendingMovies(page: number = 1): Promise<any> {
    return this.tmdbService.getTrendingMovies('week', page);
  }

  async getTrendingTvShows(page: number = 1): Promise<any> {
    return this.tmdbService.getTrendingTvShows('week', page);
  }

  async getPopularMovies(page: number = 1): Promise<any> {
    return this.tmdbService.getPopularMovies(page);
  }

  async getPopularTvShows(page: number = 1): Promise<any> {
    return this.tmdbService.getPopularTvShows(page);
  }

  async getMovieDetails(movieId: number): Promise<any> {
    return this.tmdbService.getMovieDetails(movieId);
  }

  async getTvShowDetails(tvId: number): Promise<any> {
    return this.tmdbService.getTvShowDetails(tvId);
  }

  async getTvSeasonDetails(tvId: number, seasonNumber: number): Promise<any> {
    return this.tmdbService.getTvSeasonDetails(tvId, seasonNumber);
  }

  async getMovieGenres(): Promise<any> {
    return this.tmdbService.getMovieGenres();
  }

  async getTvGenres(): Promise<any> {
    return this.tmdbService.getTvGenres();
  }

  getMovieStreamUrl(tmdbId: number | string): { embedUrl: string } {
    const embedUrl = this.vidsrcSource.getMovieEmbedUrl(tmdbId);
    this.logger.debug(`Movie stream URL requested for TMDB ID ${tmdbId}`);
    return { embedUrl };
  }

  getTvEpisodeStreamUrl(
    tmdbId: number | string,
    season: number,
    episode: number,
  ): { embedUrl: string } {
    const embedUrl = this.vidsrcSource.getTvEpisodeEmbedUrl(tmdbId, season, episode);
    this.logger.debug(
      `TV stream URL requested for TMDB ID ${tmdbId} S${season}E${episode}`,
    );
    return { embedUrl };
  }
}
