import { Injectable } from '@nestjs/common';
import axios from 'axios';

interface ConsumetAnime {
  id: string;
  title: string;
  url?: string;
  image?: string;
  releaseDate?: string;
  subOrDub?: string;
}

interface ConsumetAnimeInfo {
  id: string;
  title: string;
  url?: string;
  image?: string;
  description?: string;
  type?: string;
  releaseDate?: string;
  status?: string;
  totalEpisodes?: number;
  genres?: string[];
  episodes?: ConsumetEpisode[];
}

interface ConsumetEpisode {
  id: string;
  number: number;
  title?: string;
  url?: string;
}

interface ConsumetStreamingLinks {
  sources: Array<{
    url: string;
    quality: string;
    isM3U8: boolean;
  }>;
  download?: string;
}

/**
 * Service to interact with Consumet API for anime streaming
 * Consumet provides a unified API for scraping multiple anime sources
 *
 * Supported providers: gogoanime, 9anime, zoro, etc.
 */
@Injectable()
export class ConsumetService {
  // You can self-host Consumet or use a public instance
  // For production, self-host at: https://github.com/consumet/api.consumet.org
  private readonly baseUrl: string;
  private readonly provider: string;

  constructor() {
    // Default to a common public instance or self-hosted
    // In production, set CONSUMET_API_URL in .env
    this.baseUrl = process.env.CONSUMET_API_URL || 'https://api.consumet.org';
    this.provider = process.env.CONSUMET_PROVIDER || 'gogoanime';
  }

  /**
   * Search for anime
   */
  async searchAnime(query: string): Promise<ConsumetAnime[]> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/anime/${this.provider}/${encodeURIComponent(query)}`,
        { timeout: 10000 },
      );
      return response.data.results || [];
    } catch (error) {
      console.error('Consumet search error:', error.message);
      return [];
    }
  }

  /**
   * Get anime info including episodes list
   */
  async getAnimeInfo(animeId: string): Promise<ConsumetAnimeInfo | null> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/anime/${this.provider}/info/${encodeURIComponent(animeId)}`,
        { timeout: 10000 },
      );
      return response.data;
    } catch (error) {
      console.error('Consumet anime info error:', error.message);
      return null;
    }
  }

  /**
   * Get streaming links for an episode
   */
  async getEpisodeStreams(
    episodeId: string,
  ): Promise<ConsumetStreamingLinks | null> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/anime/${this.provider}/watch/${encodeURIComponent(episodeId)}`,
        { timeout: 15000 },
      );
      return response.data;
    } catch (error) {
      console.error('Consumet streaming error:', error.message);
      return null;
    }
  }

  /**
   * Get recent or trending anime
   */
  async getRecentEpisodes(page = 1): Promise<ConsumetAnime[]> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/anime/${this.provider}/recent-episodes`,
        {
          params: { page },
          timeout: 10000,
        },
      );
      return response.data.results || [];
    } catch (error) {
      console.error('Consumet recent episodes error:', error.message);
      return [];
    }
  }

  /**
   * Get top airing anime
   */
  async getTopAiring(page = 1): Promise<ConsumetAnime[]> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/anime/${this.provider}/top-airing`,
        {
          params: { page },
          timeout: 10000,
        },
      );
      return response.data.results || [];
    } catch (error) {
      console.error('Consumet top airing error:', error.message);
      return [];
    }
  }
}
