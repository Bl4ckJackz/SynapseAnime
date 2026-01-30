import { Controller, Get, Query, Param, UseInterceptors } from '@nestjs/common';
import { JikanAnimeService } from './jikan-anime.service';
import { JikanAnimeSearchQueryDto, JikanTopAnimeQueryDto } from './dto';
import { ErrorHandlingInterceptor } from '../common/interceptors/error-handling.interceptor';

@Controller('jikan/anime')
@UseInterceptors(ErrorHandlingInterceptor)
export class JikanAnimeController {
  constructor(private readonly jikanAnimeService: JikanAnimeService) {}

  @Get('top')
  async getTopAnime(@Query() query: JikanTopAnimeQueryDto) {
    return this.jikanAnimeService.getTopAnime(query);
  }

  @Get('new-releases')
  async getNewReleases(@Query('page') page: number = 1) {
    return this.jikanAnimeService.getNewReleases(page);
  }

  @Get('schedule')
  async getSchedule(@Query('day') day?: string) {
    return this.jikanAnimeService.getSchedule(day);
  }

  @Get('search')
  async searchAnime(@Query() query: JikanAnimeSearchQueryDto) {
    return this.jikanAnimeService.searchAnime(query);
  }

  @Get(':id')
  async getAnimeById(@Param('id') id: number) {
    return this.jikanAnimeService.getAnimeById(id);
  }

  @Get('genres')
  async getGenres() {
    return this.jikanAnimeService.getGenres();
  }

  @Get(':id/episodes')
  async getEpisodes(@Param('id') id: number) {
    return this.jikanAnimeService.getEpisodes(id);
  }
}
