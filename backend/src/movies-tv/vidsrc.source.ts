import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class VidsrcSource {
  private readonly logger = new Logger(VidsrcSource.name);
  private readonly baseUrl = 'https://vidsrc.to/embed';

  /**
   * Constructs the embed URL for a movie.
   * @param tmdbId - The TMDB ID of the movie
   * @returns The embed URL string
   */
  getMovieEmbedUrl(tmdbId: number | string): string {
    const url = `${this.baseUrl}/movie/${tmdbId}`;
    this.logger.debug(`Generated movie embed URL for TMDB ID ${tmdbId}`);
    return url;
  }

  /**
   * Constructs the embed URL for a specific TV show episode.
   * @param tmdbId - The TMDB ID of the TV show
   * @param season - The season number
   * @param episode - The episode number
   * @returns The embed URL string
   */
  getTvEpisodeEmbedUrl(
    tmdbId: number | string,
    season: number,
    episode: number,
  ): string {
    const url = `${this.baseUrl}/tv/${tmdbId}/${season}/${episode}`;
    this.logger.debug(
      `Generated TV embed URL for TMDB ID ${tmdbId} S${season}E${episode}`,
    );
    return url;
  }
}
