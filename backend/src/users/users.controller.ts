import {
  Controller,
  Get,
  Put,
  Post,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { User } from '../entities/user.entity';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import { UpdateProgressDto } from './dto/update-progress.dto';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  // --- Profile ---
  @Get('profile')
  async getProfile(@CurrentUser() user: User) {
    return this.usersService.getProfile(user.id);
  }

  @Put('profile')
  async updateProfile(
    @CurrentUser() user: User,
    @Body() body: { nickname?: string },
  ) {
    return this.usersService.updateProfile(user.id, body);
  }

  // --- Preferences ---
  @Put('preferences')
  async updatePreferences(
    @CurrentUser() user: User,
    @Body() dto: UpdatePreferencesDto,
  ) {
    return this.usersService.updatePreferences(user.id, dto);
  }

  // --- Watchlist ---
  @Get('watchlist')
  async getWatchlist(@CurrentUser() user: User) {
    return this.usersService.getWatchlist(user.id);
  }

  @Post('watchlist/:animeId')
  async addToWatchlist(
    @CurrentUser() user: User,
    @Param('animeId') animeId: string,
  ) {
    return this.usersService.addToWatchlist(user.id, animeId, 'anime');
  }

  @Delete('watchlist/:animeId')
  async removeFromWatchlist(
    @CurrentUser() user: User,
    @Param('animeId') animeId: string,
  ) {
    return this.usersService.removeFromWatchlist(user.id, animeId, 'anime');
  }

  @Get('watchlist/:animeId/check')
  async isInWatchlist(
    @CurrentUser() user: User,
    @Param('animeId') animeId: string,
  ) {
    return this.usersService.isInWatchlist(user.id, animeId, 'anime');
  }

  // Manga Endpoints
  @Post('watchlist/manga/:mangaId')
  async addMangaToWatchlist(
    @CurrentUser() user: User,
    @Param('mangaId') mangaId: string,
  ) {
    return this.usersService.addToWatchlist(user.id, mangaId, 'manga');
  }

  @Delete('watchlist/manga/:mangaId')
  async removeMangaFromWatchlist(
    @CurrentUser() user: User,
    @Param('mangaId') mangaId: string,
  ) {
    return this.usersService.removeFromWatchlist(user.id, mangaId, 'manga');
  }

  @Get('watchlist/manga/:mangaId/check')
  async isMangaInWatchlist(
    @CurrentUser() user: User,
    @Param('mangaId') mangaId: string,
  ) {
    return this.usersService.isInWatchlist(user.id, mangaId, 'manga');
  }

  // --- Watch History ---
  @Get('history')
  async getWatchHistory(
    @CurrentUser() user: User,
    @Query('limit') limit?: string,
  ) {
    return this.usersService.getWatchHistory(
      user.id,
      limit ? parseInt(limit, 10) : 20,
    );
  }

  @Get('continue-watching')
  async getContinueWatching(
    @CurrentUser() user: User,
    @Query('limit') limit?: string,
  ) {
    return this.usersService.getContinueWatching(
      user.id,
      limit ? parseInt(limit, 10) : 10,
    );
  }

  @Post('progress')
  async updateProgress(
    @CurrentUser() user: User,
    @Body() dto: UpdateProgressDto,
  ) {
    return this.usersService.updateProgress(user.id, dto);
  }

  @Get('progress/:episodeId')
  async getEpisodeProgress(
    @CurrentUser() user: User,
    @Param('episodeId') episodeId: string,
  ) {
    return this.usersService.getEpisodeProgress(user.id, episodeId);
  }

  @Get('anime/:animeId/progress')
  async getAnimeProgress(
    @CurrentUser() user: User,
    @Param('animeId') animeId: string,
  ) {
    return this.usersService.getAnimeProgress(user.id, animeId);
  }
}
