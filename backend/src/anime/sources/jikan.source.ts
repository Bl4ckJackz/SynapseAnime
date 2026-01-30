import { Injectable, Logger } from '@nestjs/common';
import { Client } from 'jikan4.js';
import {
  AnimeSource,
  AnimeFilters,
  PaginatedResult,
} from './anime-source.interface';
import { Anime, AnimeStatus } from '../../entities/anime.entity';
import { Episode } from '../../entities/episode.entity';

@Injectable()
export class JikanSource implements AnimeSource {
  readonly id = 'jikan_api';
  readonly name = 'MyAnimeList (Via Jikan)';
  readonly description = 'Real anime catalog with official streaming links';
  readonly hasDirectStream = false;

  private readonly client = new Client();
  private readonly logger = new Logger(JikanSource.name);

  async getAnimeList(filters: AnimeFilters): Promise<PaginatedResult<Anime>> {
    try {
      let data: any[] = [];

      if (filters.search) {
        const result = await this.client.anime.search(filters.search);
        data = result;
      } else {
        // Map 'new' filter to 'airing' which is Jikan's equivalent for airing/new content
        if (filters.filter === 'new') {
          // Special handling for 'new': Search for airing anime sorted by start_date desc to get actual new releases
          // We use 'any' cast to bypass potential strict typing on the wrapper's search method if needed
          const result = await (this.client.anime as any).search('', {
            status: 'airing',
            order_by: 'start_date',
            sort: 'desc',
            page: filters.page || 1,
            limit: filters.limit || 20,
          });
          data = Array.isArray(result) ? result : (result['data'] || []);
        } else {
          // Map 'airing' filter if needed (default is already airing)

          const result = await this.client.top.listAnime({
            limit: filters.limit || 20,
            filter: filters.filter as any,
            page: filters.page || 1,
          } as any);
          data = Array.isArray(result) ? result : (result['data'] || []);
        }
      }

      const animeList = data
        .filter((item: any) => item && (item.mal_id || item.malId || item.id))
        .map((item: any) => this.mapJikanToAnime(item));

      return {
        data: animeList,
        total: 1000,
        page: filters.page || 1,
        limit: filters.limit || 20,
        totalPages: 50,
      };
    } catch (e) {
      this.logger.error(`Jikan API error: ${e}`);
      return { data: [], total: 0, page: 1, limit: 20, totalPages: 0 };
    }
  }

  async getAnimeById(id: string): Promise<Anime | null> {
    try {
      const malId = parseInt(id, 10);
      if (isNaN(malId)) return null;

      const item = await this.client.anime.get(malId);
      return this.mapJikanToAnime(item);
    } catch (e) {
      return null;
    }
  }

  async getEpisodes(animeId: string): Promise<Episode[]> {
    try {
      const malId = parseInt(animeId, 10);
      if (isNaN(malId)) return [];

      const episodes = await this.client.anime.getEpisodes(malId);

      if (!episodes || !Array.isArray(episodes)) return [];

      return episodes.map((ep: any) => {
        const episode = new Episode();
        const epId = ep.mal_id || ep.malId || ep.id;
        episode.id = `${animeId}_ep_${epId}`;
        episode.animeId = animeId;
        episode.number = epId;
        episode.title = ep.title || `Episode ${epId}`;
        episode.duration = 24 * 60;
        episode.thumbnail = '';
        episode.streamUrl = ep.url || '';
        return episode;
      });
    } catch (e) {
      return [];
    }
  }

  async getStreamUrl(episodeId: string): Promise<string> {
    return '';
  }

  async getSchedule(day?: string): Promise<PaginatedResult<Anime>> {
    try {
      // Map day names to Jikan's expected format (lowercase)
      // Note: jikan4.js ScheduleDay type uses 'tursday' (typo in library) for Tuesday
      const dayMap: Record<string, any> = {
        'monday': 'monday',
        'tuesday': 'tursday', // Library typo
        'wednesday': 'wednesday',
        'thursday': 'thursday',
        'friday': 'friday',
        'saturday': 'saturday',
        'sunday': 'sunday',
      };
      const dayFilter = day?.toLowerCase();

      // Use jikan4.js schedules.list() API
      let scheduleData: any;

      if (dayFilter && dayMap[dayFilter]) {
        scheduleData = await this.client.schedules.list(dayMap[dayFilter] as any);
      } else {
        // Fetch today's schedule by default
        scheduleData = await this.client.schedules.list();
      }

      // Handle both array and object responses
      const data = Array.isArray(scheduleData)
        ? scheduleData
        : (scheduleData?.data || scheduleData || []);

      const animeList = data
        .filter((item: any) => item && (item.mal_id || item.malId || item.id))
        .map((item: any) => this.mapJikanToAnime(item));

      this.logger.log(`Schedule fetched for ${day || 'all days'}: ${animeList.length} anime`);

      return {
        data: animeList,
        total: animeList.length,
        page: 1,
        limit: 100,
        totalPages: 1,
      };
    } catch (e) {
      this.logger.error(`Schedule fetch error: ${e}`);
      return { data: [], total: 0, page: 1, limit: 100, totalPages: 0 };
    }
  }

  getExternalLink(anime: Anime): string {
    return `https://myanimelist.net/anime/${anime.id}`;
  }

  private mapJikanToAnime(item: any): Anime {
    const anime = new Anime();

    // Handle both snake_case (raw API) and camelCase (client wrapper)
    anime.id = String(item.mal_id || item.malId || item.id);

    // Title extraction - jikan4.js wrapper returns complex title object
    // Structure can be: { default: 'Title', english: 'Title EN', japanese: '日本語', synonyms: [...] }
    // Or just a plain string from raw API
    if (typeof item.title === 'string') {
      anime.title = item.title;
    } else if (item.title && typeof item.title === 'object') {
      // jikan4.js wrapper object structure
      anime.title = item.title.default || item.title.english || item.title.japanese || '';
    } else if (typeof item.titles === 'object' && Array.isArray(item.titles)) {
      // Raw API returns titles array: [{ type: 'Default', title: 'Name' }, ...]
      const defaultTitle = item.titles.find((t: any) => t.type === 'Default');
      const englishTitle = item.titles.find((t: any) => t.type === 'English');
      anime.title = defaultTitle?.title || englishTitle?.title || '';
    } else {
      anime.title = item.title_english || item.title_japanese || 'Unknown Title';
    }

    // Map English and Japanese Titles
    if (item.title && typeof item.title === 'object') {
      anime.titleEnglish = item.title.english || '';
      anime.titleJapanese = item.title.japanese || '';
    } else if (typeof item.titles === 'object' && Array.isArray(item.titles)) {
      const englishTitle = item.titles.find((t: any) => t.type === 'English');
      const japaneseTitle = item.titles.find((t: any) => t.type === 'Japanese');
      anime.titleEnglish = englishTitle?.title || '';
      anime.titleJapanese = japaneseTitle?.title || '';
    } else {
      anime.titleEnglish = item.title_english || '';
      anime.titleJapanese = item.title_japanese || '';
    }

    anime.description = typeof item.synopsis === 'string' ? item.synopsis : (item.synopsis?.default || '');

    // Images extraction - jikan4.js returns complex image object
    // Structure: { webp: { default: { href: '...' }, ... }, jpg: { ... } }
    // Or raw API: { jpg: { image_url: '...', large_image_url: '...' }, webp: { ... } }
    let coverUrl = '';
    const images = item.images || item.image || {};

    if (typeof images === 'string') {
      coverUrl = images;
    } else if (images.webp) {
      // Try webp first
      if (typeof images.webp.large_image_url === 'string') {
        coverUrl = images.webp.large_image_url;
      } else if (typeof images.webp.image_url === 'string') {
        coverUrl = images.webp.image_url;
      } else if (images.webp.large?.href) {
        coverUrl = images.webp.large.href;
      } else if (images.webp.default?.href) {
        coverUrl = images.webp.default.href;
      }
    }

    if (!coverUrl && images.jpg) {
      // Fallback to jpg
      if (typeof images.jpg.large_image_url === 'string') {
        coverUrl = images.jpg.large_image_url;
      } else if (typeof images.jpg.image_url === 'string') {
        coverUrl = images.jpg.image_url;
      } else if (images.jpg.large?.href) {
        coverUrl = images.jpg.large.href;
      } else if (images.jpg.default?.href) {
        coverUrl = images.jpg.default.href;
      }
    }

    anime.coverUrl = coverUrl;

    // Genres - handle both array of objects and array of strings
    if (Array.isArray(item.genres)) {
      anime.genres = item.genres.map((g: any) => typeof g === 'string' ? g : (g.name || g.title || ''));
    } else {
      anime.genres = [];
    }

    // Status
    const statusStr = typeof item.status === 'string'
      ? item.status
      : (item.status?.status || (item.airing ? 'Currently Airing' : 'Finished'));

    if (statusStr === 'Not yet aired') {
      anime.status = AnimeStatus.UPCOMING;
    } else if (statusStr === 'Currently Airing' || item.airing === true) {
      anime.status = AnimeStatus.ONGOING;
    } else {
      anime.status = AnimeStatus.COMPLETED;
    }

    // Duration
    anime.duration = typeof item.duration === 'string' ? item.duration : '';

    // Aired
    anime.aired = item.aired || {};

    // Year
    const airedFrom = item.aired?.from || item.airInfo?.airedFrom;
    anime.releaseYear = item.year || (airedFrom ? new Date(airedFrom).getFullYear() : 0);

    // Rating and episodes
    anime.rating = typeof item.score === 'number' ? item.score : 0;
    anime.totalEpisodes = typeof item.episodes === 'number' ? item.episodes : 0;

    return anime;
  }
}
