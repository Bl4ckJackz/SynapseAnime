import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  NotFoundException,
} from '@nestjs/common';
import { AnimeService } from './anime.service';
import { AnimeFilters } from './sources/anime-source.interface';

@Controller('anime')
export class AnimeController {
  constructor(private readonly animeService: AnimeService) { }

  @Get()
  async findAll(
    @Query('genre') genre?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const filters: AnimeFilters = {
      genre,
      status,
      search,
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 20,
    };
    return this.animeService.findAll(filters);
  }

  @Get('genres')
  async getGenres() {
    return this.animeService.getGenres();
  }

  @Get('new-releases')
  async getNewReleases(@Query('limit') limit?: string, @Query('page') page?: string) {
    return this.animeService.getNewReleases(
      limit ? parseInt(limit, 10) : 10,
      page ? parseInt(page, 10) : 1
    );
  }

  @Get('top-rated')
  async getTopRated(@Query('limit') limit?: string, @Query('page') page?: string, @Query('filter') filter?: string) {
    return this.animeService.getTopRated(
      limit ? parseInt(limit, 10) : 10,
      page ? parseInt(page, 10) : 1,
      filter
    );
  }

  @Get('sources')
  async getSources() {
    return this.animeService.getAvailableSources();
  }

  @Post('sources/:id/activate')
  async setActiveSource(@Param('id') id: string) {
    this.animeService.setActiveSource(id);
    return { success: true, activeSource: id };
  }

  @Get(':id')
  async findById(@Param('id') id: string) {
    const anime = await this.animeService.findById(id);
    if (!anime) {
      throw new NotFoundException(`Anime with ID ${id} not found`);
    }
    return anime;
  }

  @Get(':id/episodes')
  async findEpisodes(@Param('id') id: string) {
    return this.animeService.findEpisodes(id);
  }
}
