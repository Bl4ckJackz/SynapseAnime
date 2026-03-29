import {
  Controller,
  Get,
  Logger,
  Param,
  Query,
  UseInterceptors,
  Res,
} from '@nestjs/common';
import { MangaDexService } from '../services/mangadex-api.service';
import { ErrorHandlingInterceptor } from '../common/interceptors/error-handling.interceptor';
import type { Response } from 'express';
import axios from 'axios';

@Controller('mangadex')
@UseInterceptors(ErrorHandlingInterceptor)
export class MangaDexController {
  private readonly logger = new Logger(MangaDexController.name);

  constructor(private readonly mangaDexService: MangaDexService) {}

  /**
   * Health check for MangaDex API
   * GET /mangadex/health
   */
  @Get('health')
  async checkHealth() {
    try {
      // Try to make a simple request to verify API is working
      const response = await fetch('https://api.mangadex.org/manga?limit=1');
      const isHealthy = response.ok;
      return {
        service: 'mangadex',
        status: isHealthy ? 'healthy' : 'unhealthy',
        timestamp: new Date().toISOString(),
      };
    } catch {
      return {
        service: 'mangadex',
        status: 'unhealthy',
        error: 'Failed to connect to MangaDex API',
        timestamp: new Date().toISOString(),
      };
    }
  }

  /**
   * Proxy external images to bypass CORS restrictions
   * GET /mangadex/image-proxy?url=https://example.com/image.jpg
   */
  @Get('image-proxy')
  async proxyImage(@Query('url') url: string, @Res() res: Response) {
    if (!url) {
      return res.status(400).json({ error: 'URL parameter is required' });
    }

    try {
      // Decode URL if it's URL-encoded
      const decodedUrl = decodeURIComponent(url);
      this.logger.log('Image proxy fetching:', decodedUrl);

      const response = await axios.get(decodedUrl, {
        responseType: 'arraybuffer',
        timeout: 30000,
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          Accept:
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          Referer: new URL(decodedUrl).origin + '/',
          Origin: new URL(decodedUrl).origin,
        },
        validateStatus: (status) => status < 500, // Accept any status below 500
      });

      // Set CORS headers
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET');
      res.setHeader('Cache-Control', 'public, max-age=86400'); // Cache for 1 day

      // Set content type from response
      const contentType =
        (response.headers['content-type'] as string) || 'image/jpeg';
      res.setHeader('Content-Type', contentType);

      return res.send(Buffer.from(response.data));
    } catch (error: unknown) {
      const errMsg = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error('Image proxy error:', errMsg);
      this.logger.error('Failed URL:', url);
      return res.status(500).json({
        error: 'Failed to fetch image',
        message: errMsg,
        url: url.substring(0, 100),
      });
    }
  }

  /**
   * Search manga by query
   * GET /mangadex/manga/search?q=one+piece
   */
  @Get('manga/search')
  async searchManga(@Query('q') query: string) {
    if (!query) {
      return { data: [], message: 'Query parameter "q" is required' };
    }
    return this.mangaDexService.searchManga(query);
  }

  /**
   * Get manga details by MangaDex ID
   * GET /mangadex/manga/:id
   */
  @Get('manga/:id')
  async getMangaById(@Param('id') id: string) {
    return this.mangaDexService.getMangaDetails(id);
  }

  /**
   * Get manga chapters
   * GET /mangadex/manga/:id/chapters?lang=it
   */
  @Get('manga/:id/chapters')
  async getMangaChapters(
    @Param('id') id: string,
    @Query('lang') language?: string,
  ) {
    return this.mangaDexService.getChapters(id, language);
  }

  /**
   * Get chapter pages
   * GET /mangadex/chapter/:chapterId/pages
   */
  @Get('chapter/:chapterId/pages')
  async getChapterPages(@Param('chapterId') chapterId: string) {
    const pages = await this.mangaDexService.getChapterPages(chapterId);
    return { images: pages };
  }

  /**
   * Sync manga data from MangaDex to local database
   * GET /mangadex/manga/:id/sync
   */
  @Get('manga/:id/sync')
  async syncManga(@Param('id') id: string) {
    await this.mangaDexService.syncMangaData(id);
    return {
      status: 'success',
      message: `Manga ${id} synced successfully`,
    };
  }
}
