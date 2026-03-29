import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { DownloadService } from './download.service';
import { DownloadUrlDto, UpdateDownloadSettingsDto } from './dto/download.dto';

@Controller('download')
@UseGuards(JwtAuthGuard)
export class DownloadController {
  constructor(private readonly downloadService: DownloadService) {}

  @Delete('clear')
  async clearDownloads() {
    await this.downloadService.clearDownloads();
    return { message: 'Downloads cleared' };
  }

  // ========== SETTINGS ==========

  @Get('settings')
  async getSettings(@Request() req: any) {
    return this.downloadService.getSettings(req.user.id);
  }

  @Put('settings')
  async updateSettings(
    @Request() req: any,
    @Body() updates: UpdateDownloadSettingsDto,
  ) {
    return this.downloadService.updateSettings(req.user.id, updates);
  }

  // ========== DOWNLOAD QUEUE ==========

  @Get('queue')
  async getQueue(@Request() req: any) {
    return this.downloadService.getDownloadQueue(req.user.id);
  }

  @Get('history')
  async getHistory(@Request() req: any, @Query('limit') limit?: string) {
    return this.downloadService.getDownloadHistory(
      req.user.id,
      limit ? parseInt(limit, 10) : 50,
    );
  }

  // ========== DOWNLOAD ACTIONS ==========

  @Post('season/:animeId/:season')
  async downloadSeason(
    @Request() req: any,
    @Param('animeId') animeId: string,
    @Param('season') season: string,
    @Query('source') source?: string,
    @Query('title') title?: string,
  ) {
    const downloads = await this.downloadService.queueSeasonDownload(
      req.user.id,
      animeId,
      parseInt(season, 10),
      source,
      title,
    );
    return {
      message: `Queued ${downloads.length} episodes for download`,
      downloads,
    };
  }

  @Post('episode/:animeId/:episodeId')
  async downloadEpisode(
    @Request() req: any,
    @Param('animeId') animeId: string,
    @Param('episodeId') episodeId: string,
    @Query('source') source?: string,
  ) {
    const download = await this.downloadService.queueEpisodeDownload(
      req.user.id,
      animeId,
      episodeId,
      source,
    );
    return {
      message: 'Episode queued for download',
      download,
    };
  }

  @Delete(':id')
  async cancelDownload(@Request() req: any, @Param('id') id: string) {
    await this.downloadService.cancelDownload(req.user.id, id);
    return { message: 'Download cancelled' };
  }

  @Delete(':id/file')
  async deleteDownload(@Request() req: any, @Param('id') id: string) {
    await this.downloadService.deleteDownload(req.user.id, id);
    return { message: 'Download deleted' };
  }

  // ========== DIRECT URL DOWNLOAD ==========

  @Post('url')
  async downloadFromUrl(
    @Request() req: any,
    @Body() body: DownloadUrlDto,
  ) {
    const download = await this.downloadService.queueUrlDownload(
      req.user.id,
      body.url,
      body.animeName,
      body.episodeNumber,
      body.episodeTitle,
    );
    return {
      message: 'Download queued from URL',
      download,
    };
  }
}
