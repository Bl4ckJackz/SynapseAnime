import {
  Controller,
  Get,
  Param,
  Query,
  ParseIntPipe,
  UseInterceptors,
} from '@nestjs/common';
import { JikanMangaService } from './jikan-manga.service';
import { JikanSearchQueryDto, JikanTopMangaQueryDto } from './dto';
import { ErrorHandlingInterceptor } from '../common/interceptors/error-handling.interceptor';

@Controller('jikan/manga')
@UseInterceptors(ErrorHandlingInterceptor)
export class JikanMangaController {
  constructor(private readonly jikanMangaService: JikanMangaService) {}

  /**
   * Search manga by query and filters
   * GET /jikan/manga/search?q=naruto&page=1&type=manga&genres=1,2
   */
  @Get('search')
  async searchManga(@Query() query: JikanSearchQueryDto) {
    return this.jikanMangaService.searchManga(query);
  }

  /**
   * Get top manga with optional filters
   * GET /jikan/manga/top?page=1&type=manga&filter=bypopularity
   */
  @Get('top')
  async getTopManga(@Query() query: JikanTopMangaQueryDto) {
    return this.jikanMangaService.getTopManga(query);
  }

  /**
   * Get available manga genres
   * GET /jikan/manga/genres
   */
  @Get('genres')
  async getGenres() {
    return this.jikanMangaService.getGenres();
  }

  /**
   * Get manga details by MAL ID
   * GET /jikan/manga/:malId
   */
  @Get(':malId')
  async getMangaById(@Param('malId', ParseIntPipe) malId: number) {
    return this.jikanMangaService.getMangaById(malId);
  }

  /**
   * Get manga characters
   * GET /jikan/manga/:malId/characters
   */
  @Get(':malId/characters')
  async getMangaCharacters(@Param('malId', ParseIntPipe) malId: number) {
    return this.jikanMangaService.getMangaCharacters(malId);
  }

  /**
   * Get manga statistics
   * GET /jikan/manga/:malId/statistics
   */
  @Get(':malId/statistics')
  async getMangaStatistics(@Param('malId', ParseIntPipe) malId: number) {
    return this.jikanMangaService.getMangaStatistics(malId);
  }

  /**
   * Get manga recommendations
   * GET /jikan/manga/:malId/recommendations
   */
  @Get(':malId/recommendations')
  async getMangaRecommendations(@Param('malId', ParseIntPipe) malId: number) {
    return this.jikanMangaService.getMangaRecommendations(malId);
  }
}
