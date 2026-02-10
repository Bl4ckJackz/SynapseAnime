import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Res,
  NotFoundException,
} from '@nestjs/common';
import { LibraryService } from './library.service';
import type { Response } from 'express';

@Controller('library')
export class LibraryController {
  constructor(private readonly libraryService: LibraryService) { }

  @Get('folders')
  getFolders() {
    return this.libraryService.getFolders();
  }

  @Get('folder/:folderId')
  getFolderContents(@Param('folderId') folderId: string) {
    const folder = this.libraryService.getFolderById(folderId);
    if (!folder) {
      throw new NotFoundException('Folder not found');
    }
    return this.libraryService.getFolderContents(folder.path);
  }

  @Get('folder/:folderId/videos')
  getVideos(@Param('folderId') folderId: string) {
    const folder = this.libraryService.getFolderById(folderId);
    if (!folder) {
      throw new NotFoundException('Folder not found');
    }
    return this.libraryService.scanVideos(folder.path);
  }

  @Get('stream/:videoId/playlist.m3u8')
  getHlsPlaylist(
    @Param('videoId') videoId: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const videoPath = this.libraryService.getVideoPath(videoId);
    if (!videoPath) {
      throw new NotFoundException('Video not found');
    }

    res.set({
      'Content-Type': 'application/vnd.apple.mpegurl',
      'Cache-Control': 'no-cache',
    });

    return this.libraryService.generateHlsPlaylist(videoPath);
  }

  @Get('stream/:videoId/segment/:segmentId.ts')
  getHlsSegment(
    @Param('videoId') videoId: string,
    @Param('segmentId') segmentId: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const videoPath = this.libraryService.getVideoPath(videoId);
    if (!videoPath) {
      throw new NotFoundException('Video not found');
    }

    res.set({
      'Content-Type': 'video/mp2t',
      'Cache-Control': 'public, max-age=3600',
    });

    return this.libraryService.getHlsSegment(videoPath, segmentId);
  }

  @Get('stream/:videoId/direct')
  directStream(
    @Param('videoId') videoId: string,
    @Query('start') start: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const videoPath = this.libraryService.getVideoPath(videoId);
    if (!videoPath) {
      throw new NotFoundException('Video not found');
    }

    return this.libraryService.streamDirect(videoPath, res, start);
  }

  @Post('organize')
  async organizeLibrary() {
    return this.libraryService.organizeLibrary();
  }
}
