import { Controller, Get, Param, Query, UseInterceptors } from '@nestjs/common';
import { MangaDexService } from '../services/mangadex-api.service';
import { ErrorHandlingInterceptor } from '../common/interceptors/error-handling.interceptor';

@Controller('mangadex')
@UseInterceptors(ErrorHandlingInterceptor)
export class MangaDexController {
    constructor(private readonly mangaDexService: MangaDexService) { }

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
     * GET /mangadex/manga/:id/chapters
     */
    @Get('manga/:id/chapters')
    async getMangaChapters(@Param('id') id: string) {
        return this.mangaDexService.getChapters(id);
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
