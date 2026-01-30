import {
  Controller,
  Get,
  Param,
  Query,
  Req,
  NotFoundException,
} from '@nestjs/common';
import type { Request } from 'express';
import { HiAnimeSource } from './sources/hianime.source';

@Controller('anime/hianime')
export class HiAnimeController {
  constructor(private readonly hiAnimeSource: HiAnimeSource) {}

  @Get('search')
  async searchAnime(@Query('q') query: string) {
    try {
      const result = await this.hiAnimeSource.getAnimeList({
        search: query,
        page: 1,
        limit: 20,
      });
      return result.data;
    } catch (error) {
      console.error('Error searching anime on HiAnime:', error);
      return [];
    }
  }

  @Get('trending')
  async getTrendingAnime() {
    try {
      const result = await this.hiAnimeSource.getAnimeList({
        search: 'trending',
        page: 1,
        limit: 10,
      });
      return result.data;
    } catch (error) {
      console.error('Error fetching trending anime from HiAnime:', error);
      return [];
    }
  }

  @Get('popular')
  async getPopularAnime() {
    try {
      const result = await this.hiAnimeSource.getAnimeList({
        search: 'popular',
        page: 1,
        limit: 10,
      });
      return result.data;
    } catch (error) {
      console.error('Error fetching popular anime from HiAnime:', error);
      return [];
    }
  }

  @Get('details/:id')
  async getAnimeDetails(@Param('id') id: string) {
    try {
      const anime = await this.hiAnimeSource.getAnimeById(id);
      if (!anime) {
        throw new NotFoundException(`Anime with ID ${id} not found on HiAnime`);
      }
      return anime;
    } catch (error) {
      console.error(
        `Error fetching details for anime ID ${id} from HiAnime:`,
        error,
      );
      throw new NotFoundException(`Anime with ID ${id} not found on HiAnime`);
    }
  }

  @Get('episodes/:animeId')
  async getAnimeEpisodes(@Param('animeId') animeId: string) {
    try {
      const episodes = await this.hiAnimeSource.getEpisodes(animeId);
      return episodes;
    } catch (error) {
      console.error(
        `Error fetching episodes for anime ID ${animeId} from HiAnime:`,
        error,
      );
      return [];
    }
  }

  @Get('episode/*')
  async getEpisodeStreamingLinks(@Req() request: Request) {
    // Extract full episode ID from path (handles complex episode IDs)
    const fullPath = request.path;
    let episodeId = decodeURIComponent(
      fullPath.replace('/anime/hianime/episode/', ''),
    );

    // If there are query parameters, append them back to the episode ID
    if (Object.keys(request.query).length > 0) {
      const queryString = new URLSearchParams(request.query as any).toString();
      episodeId += `?${queryString}`;
    }

    try {
      const streamUrl = await this.hiAnimeSource.getStreamUrl(episodeId);

      if (!streamUrl) {
        console.log(`[HiAnime] No stream URL found for episode: ${episodeId}`);
      }

      return {
        sources: [
          {
            url: streamUrl,
            quality: 'default',
            isM3U8: streamUrl.endsWith('.m3u8'),
          },
        ],
        download: null,
      };
    } catch (error) {
      console.error(
        `Error fetching episode streaming links for ID ${episodeId} from HiAnime:`,
        error,
      );
      throw new NotFoundException(
        `Episode with ID ${episodeId} not found on HiAnime`,
      );
    }
  }
}
