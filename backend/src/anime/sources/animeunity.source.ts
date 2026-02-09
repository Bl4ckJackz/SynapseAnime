import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { Anime, AnimeStatus } from '../../entities/anime.entity';
import { Episode } from '../../entities/episode.entity';
import axios from 'axios';
import {
  AnimeSource,
  AnimeFilters,
  PaginatedResult,
} from './anime-source.interface';

@Injectable()
export class AnimeUnitySource implements AnimeSource {
  readonly id = 'animeunity';
  readonly name = 'AnimeUnity';
  readonly description = 'Streaming from AnimeUnity via local Consumet API';
  readonly hasDirectStream = true;

  // Consumet API for fallback
  private readonly consumetUrl =
    process.env.CONSUMET_API_URL || 'http://localhost:3004';
  private readonly consumetProvider = 'animeunity'; // Hardcoded as this is strictly the AnimeUnity source

  constructor(private readonly httpService: HttpService) {}

  async getAnimeList(filters: AnimeFilters): Promise<PaginatedResult<Anime>> {
    try {
      let searchQuery = filters.search;
      if (!searchQuery) {
        switch (filters.filter) {
          case 'new':
            searchQuery = 'new';
            break;
          case 'airing':
            searchQuery = 'airing';
            break;
          case 'favorite':
            searchQuery = 'best';
            break;
          default:
            searchQuery = 'popular';
        }
      }
      const url = `${this.consumetUrl}/anime/${this.consumetProvider}/${encodeURIComponent(searchQuery)}`;

      console.log(`[AnimeUnity] Requesting URL: ${url}`);

      const response = await axios.get(url, { timeout: 10000 });

      const results = response.data.results || [];
      const animes: Anime[] = results.map(
        (item: any) =>
          ({
            id: item.id,
            title: item.title,
            coverUrl: item.image,
            description: '',
            genres: [],
            status: AnimeStatus.ONGOING,
            releaseYear: item.releaseDate ? parseInt(item.releaseDate) : 0,
            rating: 0,
            totalEpisodes: 0,
          }) as any as Anime,
      );

      return {
        data: animes,
        total: animes.length,
        page: filters.page || 1,
        limit: 20,
        totalPages: response.data.hasNextPage ? 10 : 1,
      };
    } catch (error) {
      console.error('[AnimeUnity] Search failed:', error.message);
      return { data: [], total: 0, page: 1, limit: 20, totalPages: 0 };
    }
  }

  async getAnimeById(id: string): Promise<Anime | null> {
    try {
      // AnimeUnity uses ?id= query param instead of route param
      const url = `${this.consumetUrl}/anime/${this.consumetProvider}/info?id=${encodeURIComponent(id)}`;

      console.log(`[AnimeUnity] Fetching info: ${url}`);
      const response = await axios.get(url, { timeout: 10000 });

      const data = response.data;

      // Validate that we got actual anime data (not just an error message)
      if (!data || !data.id || !data.title) {
        console.log(`[AnimeUnity] No valid data for ID ${id}, returning null`);
        return null;
      }

      return {
        id: data.id,
        title: data.title,
        coverUrl: data.image,
        description: data.description || '',
        genres: data.genres || [],
        status:
          data.status === 'Completed'
            ? AnimeStatus.COMPLETED
            : AnimeStatus.ONGOING,
        releaseYear: data.releaseDate ? parseInt(data.releaseDate) : 0,
        rating: 0,
        totalEpisodes: data.totalEpisodes || data.episodes?.length || 0,
      } as any as Anime;
    } catch (error) {
      console.error('[AnimeUnity] getAnimeById failed:', error.message);
      return null;
    }
  }

  async getEpisodes(animeId: string): Promise<Episode[]> {
    try {
      // AnimeUnity uses ?id= query param instead of route param
      const url = `${this.consumetUrl}/anime/${this.consumetProvider}/info?id=${encodeURIComponent(animeId)}`;

      const response = await axios.get(url, { timeout: 10000 });

      const data = response.data;
      if (!data.episodes) return [];

      return data.episodes.map(
        (ep: any) =>
          ({
            id: ep.id,
            animeId,
            number: ep.number,
            title: ep.title || `Episode ${ep.number}`,
            duration: ep.duration || 1440, // Default to 24 mins if unknown
            thumbnail: ep.image || data.image || null,
            streamUrl: '', // Will be fetched when watching
          }) as unknown as Episode,
      );
    } catch (error) {
      console.error('[AnimeUnity] getEpisodes failed:', error.message);
      return [];
    }
  }

  async getStreamUrl(episodeId: string): Promise<string> {
    try {
      const response = await axios.get(
        `${this.consumetUrl}/anime/${this.consumetProvider}/watch/${encodeURIComponent(episodeId)}`,
        { timeout: 15000 },
      );

      const sources = response.data.sources || [];
      // Prefer 1080p, then 720p, then any available - but filter out YouTube embeds
      const preferredQualities = ['1080p', '720p', 'default', 'auto'];

      for (const quality of preferredQualities) {
        const source = sources.find(
          (s: any) =>
            s.quality?.toLowerCase().includes(quality.toLowerCase()) &&
            s.url &&
            !s.url.includes('youtube.com') &&
            !s.url.includes('youtube-nocookie.com'),
        );
        if (source) return source.url;
      }

      // Return first available non-YouTube source
      const validSource = sources.find(
        (s: any) =>
          s.url &&
          !s.url.includes('youtube.com') &&
          !s.url.includes('youtube-nocookie.com'),
      );
      if (validSource) {
        return validSource.url;
      }

      console.log('[AnimeUnity] No valid video sources found');
      return '';
    } catch (error) {
      console.error('[AnimeUnity] getStreamUrl failed:', error.message);
      return '';
    }
  }
}
