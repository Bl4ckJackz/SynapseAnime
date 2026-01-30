import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AnimeFilters } from './sources/anime-source.interface';
import { SourceManager } from './sources/source.manager';
import { Anime } from '../entities/anime.entity';
import { Episode } from '../entities/episode.entity';
import { AnimeStreamingService } from '../services/anime-streaming.service';

@Injectable()
export class AnimeService {
  constructor(
    private readonly sourceManager: SourceManager,
    private readonly animeStreamingService: AnimeStreamingService,
    @InjectRepository(Anime)
    private animeRepository: Repository<Anime>,
    @InjectRepository(Episode)
    private episodeRepository: Repository<Episode>,
  ) {}

  async findAll(filters: AnimeFilters) {
    return this.sourceManager.getActiveSource().getAnimeList(filters);
  }

  async findById(id: string): Promise<Anime | null> {
    const source = this.sourceManager.getActiveSource();
    let anime = await source.getAnimeById(id);

    if (anime) {
      // If it's an external provider (not DB), try to enrichment with Jikan if possible
      if (source.id !== 'default_db' && anime.title) {
        try {
          // You might have a way to search Jikan by title or malId
          // For now, if we have malId, we could use it.
          // Let's assume for now we trust the provider for the most "on the ground" info
          // but could backup with more descriptive info if missing.
          // If totalEpisodes is 0 or low, and we have another source for it, we could merge.
          // But usually provider is the one with the actual streamable episodes.
        } catch (e) {
          // ignore enrichment errors
        }
      }

      if (source.getExternalLink) {
        const externalLink = source.getExternalLink(anime);
        if (externalLink) {
          anime.description = `${anime.description}\n\n[EXTERNAL_LINK]${externalLink}[/EXTERNAL_LINK]`;
        }
      }

      // Persist to local DB
      try {
        await this.animeRepository.save(anime);
      } catch (e) {
        console.error(`Error persisting anime ${id}:`, e);
      }
    }
    return anime;
  }

  async findEpisodes(animeId: string): Promise<Episode[]> {
    const source = this.sourceManager.getActiveSource();

    // Always fetch from source to get freshest data (esp. for airing anime)
    const sourceEpisodes = await source.getEpisodes(animeId);

    // Save/Update episodes to database for future use (history tracking)
    for (const ep of sourceEpisodes) {
      ep.animeId = animeId;
      try {
        await this.episodeRepository.save(ep);
      } catch (e) {
        // Silently fail if save fails (e.g. duplicate or DB issue)
      }
    }

    return sourceEpisodes;
  }

  async getGenres(): Promise<string[]> {
    // Genres fetching might depend on source capabilities.
    // For now, we fallback to DefaultDbSource logic or empty if not supported.
    // Ideally AnimeSource should have getGenres(), but let's keep it simple.
    // If active source is DefaultDbSource, we can cast and call specific methods or just return mock data for others.

    // For this demo, let's assume standard genres if not DB source
    if (this.sourceManager.getActiveSource().id === 'default_db') {
      // We can iterate all sources or just use static list for consistency
      return [
        'Action',
        'Adventure',
        'Comedy',
        'Cyberpunk',
        'Drama',
        'Fantasy',
        'Food',
        'Horror',
        'Isekai',
        'Mecha',
        'Music',
        'Mystery',
        'Political',
        'Psychological',
        'Romance',
        'Samurai',
        'School',
        'Sci-Fi',
        'Slice of Life',
        'Space',
        'Sports',
        'Supernatural',
      ];
    }
    return ['Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy', 'Sci-Fi'];
  }

  async getNewReleases(limit = 10, page = 1): Promise<Anime[]> {
    try {
      const result = await this.sourceManager
        .getActiveSource()
        .getAnimeList({ limit, page });
      if (result.data.length > 0) return result.data;
      throw new Error('No items found');
    } catch (error) {
      console.warn(
        `[AnimeService] Failed to fetch new releases from active source, falling back to Jikan: ${error.message}`,
      );
      const jikanSource = this.sourceManager.getSource('jikan_api');
      if (jikanSource) {
        const fallback = await jikanSource.getAnimeList({ limit, page });
        return fallback.data;
      }
      return [];
    }
  }

  async getTopRated(limit = 10, page = 1, filter?: string): Promise<Anime[]> {
    try {
      const result = await this.sourceManager
        .getActiveSource()
        .getAnimeList({ limit, page, filter });
      if (result.data.length > 0) return result.data;
      throw new Error('No items found');
    } catch (error) {
      console.warn(
        `[AnimeService] Failed to fetch top rated from active source, falling back to Jikan: ${error.message}`,
      );
      const jikanSource = this.sourceManager.getSource('jikan_api');
      if (jikanSource) {
        const fallback = await jikanSource.getAnimeList({
          limit,
          page,
          filter,
        });
        return fallback.data;
      }
      return [];
    }
  }

  async findByIds(ids: string[]): Promise<Anime[]> {
    // This is used by Recommendations.
    // Optimization: fetches in parallel
    const activeSource = this.sourceManager.getActiveSource();
    const promises = ids.map((id) => activeSource.getAnimeById(id));
    const results = await Promise.all(promises);
    return results.filter((a): a is Anime => a !== null);
  }

  getAvailableSources() {
    return this.sourceManager.getSources();
  }

  setActiveSource(sourceId: string) {
    this.sourceManager.setActiveSource(sourceId);
  }

  async getStreamingSources(animeId: string, episodeNumber: number) {
    return await this.animeStreamingService.getStreamingSources(
      animeId,
      episodeNumber,
    );
  }

  async getRecommendedEpisodes(
    animeId: string,
    currentEpisode: number,
    count: number = 3,
  ) {
    return await this.animeStreamingService.getRecommendedEpisodes(
      animeId,
      currentEpisode,
      count,
    );
  }

  async getEpisodeWithFallbackSources(animeId: string, episodeNumber: number) {
    return await this.animeStreamingService.getEpisodeWithFallbackSources(
      animeId,
      episodeNumber,
    );
  }
}
