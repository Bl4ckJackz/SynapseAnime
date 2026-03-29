import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import { Anime } from '../entities/anime.entity';
import { Episode } from '../entities/episode.entity';
import { StreamingSource } from '../types/streaming.types';

@Injectable()
export class AnimeStreamingService {
  private readonly logger = new Logger(AnimeStreamingService.name);

  constructor(
    @InjectRepository(Anime)
    private animeRepository: Repository<Anime>,
    @InjectRepository(Episode)
    private episodeRepository: Repository<Episode>,
  ) {}

  async getStreamingSources(
    animeId: string,
    episodeNumber: number,
  ): Promise<StreamingSource[]> {
    try {
      // First, try to get the episode from our database
      const episode = await this.episodeRepository.findOne({
        where: {
          animeId,
          number: episodeNumber,
        },
      });

      if (episode && episode.streamUrl) {
        // If we have a stored stream URL, return it as a source
        return [
          {
            type: 'internal',
            provider: 'internal-cdn',
            url: episode.streamUrl,
            quality: '720p', // Default assumption
            language: 'sub', // Default assumption
            priority: 1,
          },
        ];
      }

      // If no internal source, we could implement logic to fetch from external sources
      // For now, return an empty array indicating no sources found
      return [];
    } catch (error) {
      this.logger.error(
        `Error getting streaming sources for anime ${animeId}, episode ${episodeNumber}:`,
        error,
      );
      throw new Error(`Failed to get streaming sources`);
    }
  }

  async uploadInternalSource(file: Buffer, metadata: any): Promise<string> {
    // In a real implementation, this would upload to a cloud storage service
    // For now, we'll simulate the process and return a mock URL
    this.logger.log(
      `Uploading file for anime: ${metadata.animeId}, episode: ${metadata.episodeNumber}`,
    );

    // This would actually upload to S3, Cloudinary, or similar service
    // For simulation, return a mock URL
    return `https://internal-cdn.example.com/videos/${metadata.animeId}/episode-${metadata.episodeNumber}.mp4`;
  }

  async validateDirectLink(url: string): Promise<boolean> {
    // In a real implementation, this would validate that the URL is accessible
    // and returns appropriate video content
    try {
      // This is a simplified validation - in reality, you'd make a HEAD request
      // to check if the URL returns proper video content headers
      return (
        url.startsWith('http') &&
        (url.endsWith('.mp4') || url.endsWith('.m3u8'))
      );
    } catch (error) {
      this.logger.error(`Error validating direct link ${url}:`, error);
      return false;
    }
  }

  async getAvailableProviders(): Promise<string[]> {
    // Return list of available streaming providers
    // This could be extended to include external providers like Crunchyroll, Funimation, etc.
    return [
      'internal-cdn',
      'gogoanime',
      'crunchyroll',
      'funimation',
      'netflix-style-streaming',
    ];
  }

  async addStreamingSource(
    animeId: string,
    episodeNumber: number,
    source: StreamingSource,
  ): Promise<void> {
    // Add a new streaming source to an episode
    const episode = await this.episodeRepository.findOne({
      where: {
        animeId,
        number: episodeNumber,
      },
    });

    if (!episode) {
      throw new Error(
        `Episode ${episodeNumber} not found for anime ${animeId}`,
      );
    }

    // In a real implementation, we would store the source information
    // For now, we'll just update the streamUrl with the new source
    episode.streamUrl = source.url;
    await this.episodeRepository.save(episode);
  }

  async getRecommendedEpisodes(
    animeId: string,
    currentEpisode: number,
    count: number = 3,
  ): Promise<Episode[]> {
    // Get episodes that come after the current episode
    return await this.episodeRepository.find({
      where: {
        animeId,
        number: MoreThan(currentEpisode),
      },
      order: {
        number: 'ASC',
      },
      take: count,
    });
  }

  async getEpisodeWithFallbackSources(
    animeId: string,
    episodeNumber: number,
  ): Promise<{
    episode: Episode;
    sources: StreamingSource[];
  }> {
    const episode = await this.episodeRepository.findOne({
      where: {
        animeId,
        number: episodeNumber,
      },
    });

    if (!episode) {
      throw new Error(
        `Episode ${episodeNumber} not found for anime ${animeId}`,
      );
    }

    // Get all available sources for this episode
    const sources = await this.getStreamingSources(animeId, episodeNumber);

    return {
      episode,
      sources,
    };
  }
}
