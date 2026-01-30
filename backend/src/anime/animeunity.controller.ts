import {
  Controller,
  Get,
  Param,
  Query,
  Req,
  NotFoundException,
} from '@nestjs/common';
import type { Request } from 'express';
import { AnimeUnitySource } from './sources/animeunity.source';

@Controller('anime/animeunity')
export class AnimeUnityController {
  constructor(private readonly animeUnitySource: AnimeUnitySource) {}

  @Get('search')
  async searchAnime(@Query('q') query: string) {
    try {
      const result = await this.animeUnitySource.getAnimeList({
        search: query,
        page: 1,
        limit: 20,
      });
      return result.data;
    } catch (error) {
      console.error('Error searching anime on AnimeUnity:', error);
      return [];
    }
  }

  @Get('trending')
  async getTrendingAnime() {
    try {
      const result = await this.animeUnitySource.getAnimeList({
        search: 'trending',
        page: 1,
        limit: 10,
      });
      return result.data;
    } catch (error) {
      console.error('Error fetching trending anime from AnimeUnity:', error);
      return [];
    }
  }

  @Get('popular')
  async getPopularAnime() {
    try {
      const result = await this.animeUnitySource.getAnimeList({
        search: 'popular',
        page: 1,
        limit: 10,
      });
      return result.data;
    } catch (error) {
      console.error('Error fetching popular anime from AnimeUnity:', error);
      return [];
    }
  }

  @Get('details/:id')
  async getAnimeDetails(@Param('id') id: string) {
    try {
      const anime = await this.animeUnitySource.getAnimeById(id);
      if (!anime) {
        throw new NotFoundException(
          `Anime with ID ${id} not found on AnimeUnity`,
        );
      }
      return anime;
    } catch (error) {
      console.error(
        `Error fetching details for anime ID ${id} from AnimeUnity:`,
        error,
      );
      throw new NotFoundException(
        `Anime with ID ${id} not found on AnimeUnity`,
      );
    }
  }

  @Get('episodes/:animeId')
  async getAnimeEpisodes(@Param('animeId') animeId: string) {
    try {
      const episodes = await this.animeUnitySource.getEpisodes(animeId);
      return episodes;
    } catch (error) {
      console.error(
        `Error fetching episodes for anime ID ${animeId} from AnimeUnity:`,
        error,
      );
      return [];
    }
  }

  @Get('episode/*')
  async getEpisodeStreamingLinks(@Req() request: Request) {
    // Extract full episode ID from path (handles slashes in episode IDs)
    const fullPath = request.path;
    const episodeId = decodeURIComponent(
      fullPath.replace('/anime/animeunity/episode/', ''),
    );

    // If there are query parameters (e.g. ?server=...), they are usually not part of the ID for Consumet
    // but specific to the request. The ID itself should be clean.

    try {
      // Get stream URL for the episode
      const streamUrl = await this.animeUnitySource.getStreamUrl(episodeId);

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
        `Error fetching episode streaming links for ID ${episodeId} from AnimeUnity:`,
        error,
      );
      throw new NotFoundException(
        `Episode with ID ${episodeId} not found on AnimeUnity`,
      );
    }
  }
}
