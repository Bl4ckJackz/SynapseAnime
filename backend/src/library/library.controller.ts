import {
    Controller,
    Get,
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
    async getFolderContents(@Param('folderId') folderId: string) {
        const folder = await this.libraryService.getFolderById(folderId);
        if (!folder) {
            throw new NotFoundException('Folder not found');
        }
        return this.libraryService.getFolderContents(folder.path);
    }

    @Get('folder/:folderId/videos')
    async getVideos(@Param('folderId') folderId: string) {
        const folder = await this.libraryService.getFolderById(folderId);
        if (!folder) {
            throw new NotFoundException('Folder not found');
        }
        return this.libraryService.scanVideos(folder.path);
    }

    @Get('stream/:videoId/playlist.m3u8')
    async getHlsPlaylist(
        @Param('videoId') videoId: string,
        @Res({ passthrough: true }) res: Response,
    ) {
        const videoPath = await this.libraryService.getVideoPath(videoId);
        if (!videoPath) {
            throw new NotFoundException('Video not found');
        }

        res.set({
            'Content-Type': 'application/vnd.apple.mpegurl',
            'Cache-Control': 'no-cache',
        });

        return this.libraryService.generateHlsPlaylist(videoPath, videoId);
    }

    @Get('stream/:videoId/segment/:segmentId.ts')
    async getHlsSegment(
        @Param('videoId') videoId: string,
        @Param('segmentId') segmentId: string,
        @Res({ passthrough: true }) res: Response,
    ) {
        const videoPath = await this.libraryService.getVideoPath(videoId);
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
    async directStream(
        @Param('videoId') videoId: string,
        @Query('start') start: string,
        @Res({ passthrough: true }) res: Response,
    ) {
        const videoPath = await this.libraryService.getVideoPath(videoId);
        if (!videoPath) {
            throw new NotFoundException('Video not found');
        }

        return this.libraryService.streamDirect(videoPath, res, start);
    }
}
