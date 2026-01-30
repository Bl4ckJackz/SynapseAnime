import { Controller, Get, Param, Query, UseInterceptors } from '@nestjs/common';
import { MangaHookService } from './mangahook.service';
import { MangaHookListQueryDto, MangaHookSearchQueryDto } from './dto';
import { ErrorHandlingInterceptor } from '../common/interceptors/error-handling.interceptor';

@Controller('mangahook')
@UseInterceptors(ErrorHandlingInterceptor)
export class MangaHookController {
  constructor(private readonly mangaHookService: MangaHookService) {}

  /**
   * Get paginated manga list with filters
   * GET /mangahook/manga?page=1&type=newest&category=all&state=Completed
   */
  @Get('manga')
  async getMangaList(@Query() query: MangaHookListQueryDto) {
    return this.mangaHookService.getMangaList(query);
  }

  /**
   * Search manga by query
   * GET /mangahook/manga/search?q=attack&page=1
   */
  @Get('manga/search')
  async searchManga(@Query() query: MangaHookSearchQueryDto) {
    return this.mangaHookService.searchManga(query);
  }

  /**
   * Get available filters (types, states, categories)
   * GET /mangahook/filters
   */
  @Get('filters')
  async getFilters() {
    return this.mangaHookService.getFilters();
  }

  /**
   * Health check for Manga Hook API
   * GET /mangahook/health
   */
  @Get('health')
  async checkHealth() {
    const isHealthy = await this.mangaHookService.checkHealth();
    return {
      service: 'mangahook',
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Get manga details by ID
   * GET /mangahook/manga/:id
   */
  @Get('manga/:id')
  async getMangaById(@Param('id') id: string) {
    return this.mangaHookService.getMangaById(id);
  }

  /**
   * Get chapter images
   * GET /mangahook/manga/:mangaId/chapter/:chapterId
   */
  @Get('manga/:mangaId/chapter/:chapterId')
  async getChapterImages(
    @Param('mangaId') mangaId: string,
    @Param('chapterId') chapterId: string,
  ) {
    return this.mangaHookService.getChapterImages(mangaId, chapterId);
  }
}
