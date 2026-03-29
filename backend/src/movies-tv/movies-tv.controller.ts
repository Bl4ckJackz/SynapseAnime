import {
  Controller,
  Get,
  Query,
  Param,
  ParseIntPipe,
  UseInterceptors,
} from '@nestjs/common';
import { MoviesTvService } from './movies-tv.service';
import { MoviesTvSearchDto } from './dto/movies-tv-search.dto';
import { ErrorHandlingInterceptor } from '../common/interceptors/error-handling.interceptor';

@Controller('movies-tv')
@UseInterceptors(ErrorHandlingInterceptor)
export class MoviesTvController {
  constructor(private readonly moviesTvService: MoviesTvService) {}

  @Get('search')
  async search(@Query() query: MoviesTvSearchDto) {
    return this.moviesTvService.search(query);
  }

  @Get('movies/trending')
  async getTrendingMovies(@Query('page') page: number = 1) {
    return this.moviesTvService.getTrendingMovies(page);
  }

  @Get('tv/trending')
  async getTrendingTvShows(@Query('page') page: number = 1) {
    return this.moviesTvService.getTrendingTvShows(page);
  }

  @Get('movies/popular')
  async getPopularMovies(@Query('page') page: number = 1) {
    return this.moviesTvService.getPopularMovies(page);
  }

  @Get('tv/popular')
  async getPopularTvShows(@Query('page') page: number = 1) {
    return this.moviesTvService.getPopularTvShows(page);
  }

  @Get('movies/genres')
  async getMovieGenres() {
    return this.moviesTvService.getMovieGenres();
  }

  @Get('tv/genres')
  async getTvGenres() {
    return this.moviesTvService.getTvGenres();
  }

  @Get('movies/:id')
  async getMovieDetails(@Param('id', ParseIntPipe) id: number) {
    return this.moviesTvService.getMovieDetails(id);
  }

  @Get('tv/:id/season/:season')
  async getTvSeasonDetails(
    @Param('id', ParseIntPipe) id: number,
    @Param('season', ParseIntPipe) season: number,
  ) {
    return this.moviesTvService.getTvSeasonDetails(id, season);
  }

  @Get('tv/:id')
  async getTvShowDetails(@Param('id', ParseIntPipe) id: number) {
    return this.moviesTvService.getTvShowDetails(id);
  }

  @Get('stream/movie/:tmdbId')
  getMovieStream(@Param('tmdbId', ParseIntPipe) tmdbId: number) {
    return this.moviesTvService.getMovieStreamUrl(tmdbId);
  }

  @Get('stream/tv/:tmdbId/:season/:episode')
  getTvEpisodeStream(
    @Param('tmdbId', ParseIntPipe) tmdbId: number,
    @Param('season', ParseIntPipe) season: number,
    @Param('episode', ParseIntPipe) episode: number,
  ) {
    return this.moviesTvService.getTvEpisodeStreamUrl(tmdbId, season, episode);
  }
}
