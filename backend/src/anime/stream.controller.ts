import {
  Controller,
  Get,
  Logger,
  Param,
  Res,
  StreamableFile,
  NotFoundException,
  Query,
} from '@nestjs/common';
import type { Response } from 'express';
import * as fs from 'fs';
import { LocalFileSource } from './sources/local-file.source';
import axios from 'axios';

@Controller('stream')
export class StreamController {
  private readonly logger = new Logger(StreamController.name);

  constructor(private readonly localSource: LocalFileSource) {}

  @Get('local/:animeId/:filename')
  streamLocalVideo(
    @Param('animeId') animeId: string,
    @Param('filename') filename: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    const videoPath = this.localSource.getVideoPath(animeId, filename);

    if (!videoPath || !fs.existsSync(videoPath)) {
      throw new NotFoundException('Video file not found');
    }

    const stat = fs.statSync(videoPath);
    const fileSize = stat.size;
    const range = 'bytes=0-'; // Simple full stream for demo, range request logic needed for seek

    // Basic streaming headers
    res.set({
      'Content-Length': fileSize,
      'Content-Type': 'video/mp4', // auto-detect would be better
    });

    const file = fs.createReadStream(videoPath);
    return new StreamableFile(file);
  }
  @Get('proxy-image')
  async proxyImage(
    @Query('url') url: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    if (!url) {
      throw new NotFoundException('URL is required');
    }

    try {
      // Determine appropriate headers based on URL
      const isAnimeUnity = url.includes('animeunity');
      const headers: Record<string, string> = {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        Accept:
          'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      };

      if (isAnimeUnity) {
        headers['Referer'] = 'https://www.animeunity.to/';
      } else {
        headers['Referer'] = new URL(url).origin;
      }

      const response = await axios.get(url, {
        responseType: 'stream',
        headers,
        timeout: 10000,
      });

      res.set({
        'Content-Type': response.headers['content-type'] || 'image/jpeg',
        'Cache-Control': 'public, max-age=86400',
        'Access-Control-Allow-Origin': '*',
      });

      return new StreamableFile(response.data);
    } catch (error) {
      this.logger.error(`[Proxy] Failed to fetch image: ${url}`, error.message);
      throw new NotFoundException('Failed to fetch image');
    }
  }
}
