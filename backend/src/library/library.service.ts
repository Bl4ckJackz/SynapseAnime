import { Injectable, Logger, StreamableFile } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { spawn } from 'child_process';
import { Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import * as ffmpeg from 'fluent-ffmpeg';

/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/* eslint-disable @typescript-eslint/no-unsafe-member-access */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
// eslint-disable-next-line
const ffmpegInstaller = require('ffmpeg-static');
// eslint-disable-next-line
const ffprobeInstaller = require('ffprobe-static');

ffmpeg.setFfmpegPath(ffmpegInstaller);
ffmpeg.setFfprobePath(ffprobeInstaller.path);

export interface LibraryFolder {
  id: string;
  name: string;
  path: string;
  type: 'anime' | 'manga' | 'mixed';
}

interface VideoFile {
  id: string;
  filename: string;
  path: string;
  title: string;
  episode: number;
  size: number;
}

export interface LocalAnime {
  title: string;
  episodes: VideoFile[];
}

@Injectable()
export class LibraryService {
  private readonly logger = new Logger(LibraryService.name);
  private folders: LibraryFolder[] = [];
  private videoRegistry: Map<string, string> = new Map();

  constructor() {
    this.loadFolders();
  }

  private loadFolders() {
    const libraryPath =
      process.env.LIBRARY_PATH || path.join(process.cwd(), 'video_library');
    this.folders = [
      {
        id: 'default',
        name: 'Anime Library',
        path: libraryPath,
        type: 'anime',
      },
    ];
  }

  getFolders(): LibraryFolder[] {
    return this.folders;
  }

  getFolderById(folderId: string): LibraryFolder | undefined {
    return this.folders.find((f) => f.id === folderId);
  }

  addFolder(
    name: string,
    folderPath: string,
    type: 'anime' | 'manga' | 'mixed' = 'anime',
  ): LibraryFolder {
    const folder: LibraryFolder = {
      id: uuidv4(),
      name,
      path: folderPath,
      type,
    };
    this.folders.push(folder);
    return folder;
  }

  async getFolderContents(folderPath: string): Promise<string[]> {
    try {
      const entries = await fs.promises.readdir(folderPath, {
        withFileTypes: true,
      });
      return entries.filter((e) => e.isDirectory()).map((e) => e.name);
    } catch (error) {
      this.logger.error('Error reading folder:', error);
      return [];
    }
  }

  async scanVideos(folderPath: string): Promise<LocalAnime[]> {
    const groupedEpisodes: Map<string, VideoFile[]> = new Map();

    try {
      await this.scanRecursive(folderPath, groupedEpisodes);
    } catch (error) {
      this.logger.error('Error scanning videos:', error);
    }

    const animes: LocalAnime[] = [];
    groupedEpisodes.forEach((episodes, title) => {
      episodes.sort((a, b) => a.episode - b.episode);
      animes.push({ title, episodes });
    });

    animes.sort((a, b) => a.title.localeCompare(b.title));
    return animes;
  }

  private async scanRecursive(
    dirPath: string,
    groupedEpisodes: Map<string, VideoFile[]>,
  ) {
    const entries = await fs.promises.readdir(dirPath, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dirPath, entry.name);

      if (entry.isDirectory()) {
        await this.scanRecursive(fullPath, groupedEpisodes);
      } else if (entry.isFile()) {
        const ext = path.extname(entry.name).toLowerCase();
        if (['.mp4', '.mkv', '.avi', '.mov', '.webm'].includes(ext)) {
          const parsed = this.parseFilename(entry.name);
          const videoId = uuidv4();

          this.videoRegistry.set(videoId, fullPath);

          const stat = await fs.promises.stat(fullPath);

          const video: VideoFile = {
            id: videoId,
            filename: entry.name,
            path: fullPath,
            title: parsed.title,
            episode: parsed.episode,
            size: stat.size,
          };

          if (!groupedEpisodes.has(parsed.title)) {
            groupedEpisodes.set(parsed.title, []);
          }
          groupedEpisodes.get(parsed.title)!.push(video);
        }
      }
    }
  }

  private parseFilename(filename: string): { title: string; episode: number } {
    const regex = /(?:\[.*?\]\s*)?([^-]+?)\s*-\s*(\d+)/i;
    const match = regex.exec(filename);

    if (match) {
      return {
        title: match[1].trim(),
        episode: parseInt(match[2], 10),
      };
    }

    return {
      title: path.basename(filename, path.extname(filename)),
      episode: 0,
    };
  }

  getVideoPath(videoId: string): string | undefined {
    return this.videoRegistry.get(videoId);
  }

  async getVideoDuration(videoPath: string): Promise<number> {
    return new Promise((resolve, reject) => {
      ffmpeg.ffprobe(videoPath, (err, metadata) => {
        if (err) {
          reject(new Error(String(err)));
        } else {
          resolve(metadata.format.duration || 0);
        }
      });
    });
  }

  async generateHlsPlaylist(videoPath: string): Promise<string> {
    const segmentDuration = 10;
    let duration = 0;
    try {
      duration = await this.getVideoDuration(videoPath);
    } catch (error) {
      this.logger.error('Error getting video duration:', error);
      duration = 1800; // Fallback 30 mins
    }

    let playlist = '#EXTM3U\n';
    playlist += '#EXT-X-VERSION:3\n';
    playlist += `#EXT-X-TARGETDURATION:${segmentDuration}\n`;
    playlist += '#EXT-X-MEDIA-SEQUENCE:0\n';

    const numSegments = Math.ceil(duration / segmentDuration);
    for (let i = 0; i < numSegments; i++) {
      playlist += `#EXTINF:${segmentDuration},\n`;
      playlist += `segment/${i}.ts\n`;
    }
    playlist += '#EXT-X-ENDLIST\n';

    return playlist;
  }

  async getHlsSegment(
    videoPath: string,
    segmentId: string,
  ): Promise<StreamableFile> {
    const segmentNum = parseInt(segmentId, 10);
    const segmentDuration = 10;
    const startTime = segmentNum * segmentDuration;

    return new Promise((resolve, reject) => {
      const chunks: Buffer[] = [];

      const ffmpeg = spawn(ffmpegInstaller, [
        '-ss',
        startTime.toString(),
        '-i',
        videoPath,
        '-t',
        segmentDuration.toString(),
        '-c:v',
        'libx264',
        '-c:a',
        'aac',
        '-preset',
        'ultrafast',
        '-f',
        'mpegts',
        '-',
      ]);

      ffmpeg.stdout.on('data', (chunk) => {
        chunks.push(chunk);
      });

      ffmpeg.on('close', (code) => {
        if (code === 0) {
          const buffer = Buffer.concat(chunks);
          resolve(new StreamableFile(buffer));
        } else {
          reject(new Error(`FFmpeg exited with code ${code}`));
        }
      });

      ffmpeg.on('error', reject);
    });
  }

  async streamDirect(
    videoPath: string,
    res: Response,
    start?: string,
  ): Promise<StreamableFile> {
    const stat = await fs.promises.stat(videoPath);
    const fileSize = stat.size;
    const startByte = start ? parseInt(start, 10) : 0;

    res.set({
      'Content-Type': 'video/mp4',
      'Content-Length': String(fileSize - startByte),
      'Accept-Ranges': 'bytes',
    });

    const stream = fs.createReadStream(videoPath, { start: startByte });
    return new StreamableFile(stream);
  }

  /**
   * Organize all loose video files in the library.
   * Renames files using standardized format and moves them into proper folders.
   */
  async organizeLibrary(): Promise<{
    organized: number;
    skipped: number;
    errors: string[];
  }> {
    const libraryPath =
      process.env.LIBRARY_PATH || path.join(process.cwd(), 'video_library');

    let organized = 0;
    let skipped = 0;
    const errors: string[] = [];

    this.logger.log('[OrganizeService] Starting library organization...');

    try {
      const looseFiles = await this.findLooseFiles(libraryPath);
      this.logger.log(`[OrganizeService] Found ${looseFiles.length} loose files`);

      for (const filePath of looseFiles) {
        try {
          const filename = path.basename(filePath);
          const parsed = this.parseFilenameAdvanced(filename);

          if (!parsed.title || parsed.episode === 0) {
            this.logger.log(`[OrganizeService] Skipping unparseable: ${filename}`);
            skipped++;
            continue;
          }

          // Create folder structure: AnimeTitle/Season 1/
          const seasonFolder = `Season ${parsed.season}`;
          const animeFolder = path.join(libraryPath, parsed.title, seasonFolder);
          await fs.promises.mkdir(animeFolder, { recursive: true });

          // New filename: Title S01E01.ext
          const ext = path.extname(filename);
          const episodeNum = String(parsed.episode).padStart(2, '0');
          const seasonNum = String(parsed.season).padStart(2, '0');
          const newFilename = `${parsed.title} S${seasonNum}E${episodeNum}${ext}`;
          const newPath = path.join(animeFolder, newFilename);

          // Check if file already exists
          if (fs.existsSync(newPath)) {
            this.logger.log(`[OrganizeService] Already exists: ${newFilename}`);
            skipped++;
            continue;
          }

          // Move file
          await fs.promises.rename(filePath, newPath);
          this.logger.log(`[OrganizeService] Moved: ${filename} -> ${newFilename}`);
          organized++;
        } catch (err) {
          const errorMsg = `Error processing ${filePath}: ${err}`;
          this.logger.error(`[OrganizeService] ${errorMsg}`);
          errors.push(errorMsg);
        }
      }
    } catch (err) {
      this.logger.error('[OrganizeService] Critical error:', err);
      errors.push(`Critical error: ${err}`);
    }

    this.logger.log(
      `[OrganizeService] Complete: ${organized} organized, ${skipped} skipped, ${errors.length} errors`,
    );

    return { organized, skipped, errors };
  }

  /**
   * Find video files that are directly in the library root (not in anime folders)
   */
  private async findLooseFiles(libraryPath: string): Promise<string[]> {
    const looseFiles: string[] = [];
    const videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.webm'];

    try {
      const entries = await fs.promises.readdir(libraryPath, {
        withFileTypes: true,
      });

      for (const entry of entries) {
        const fullPath = path.join(libraryPath, entry.name);

        if (entry.isFile()) {
          const ext = path.extname(entry.name).toLowerCase();
          if (videoExtensions.includes(ext)) {
            looseFiles.push(fullPath);
          }
        }
      }
    } catch (err) {
      this.logger.error('[OrganizeService] Error scanning for loose files:', err);
    }

    return looseFiles;
  }

  /**
   * Advanced filename parser that extracts title, season, and episode
   */
  private parseFilenameAdvanced(filename: string): {
    title: string;
    season: number;
    episode: number;
  } {
    // Remove extension
    const nameWithoutExt = path.basename(filename, path.extname(filename));

    // Common patterns:
    // [Fansub] Title - 01 [1080p]
    // Title S01E01
    // Title - 01
    // Title Episode 01

    // Try S01E01 format first
    const s01e01Match = /(.+?)\s*S(\d+)E(\d+)/i.exec(nameWithoutExt);
    if (s01e01Match) {
      return {
        title: s01e01Match[1].trim().replace(/[[\]]/g, ''),
        season: parseInt(s01e01Match[2], 10),
        episode: parseInt(s01e01Match[3], 10),
      };
    }

    // Try [Fansub] Title - 01 format
    const fansubMatch = /(?:\[.*?\]\s*)?([^-]+?)\s*-\s*(\d+)/i.exec(nameWithoutExt);
    if (fansubMatch) {
      return {
        title: fansubMatch[1].trim().replace(/[[\]]/g, ''),
        season: 1,
        episode: parseInt(fansubMatch[2], 10),
      };
    }

    // Try "Episode X" format
    const episodeMatch = /(.+?)\s*(?:Episode|Ep\.?)\s*(\d+)/i.exec(nameWithoutExt);
    if (episodeMatch) {
      return {
        title: episodeMatch[1].trim().replace(/[[\]]/g, ''),
        season: 1,
        episode: parseInt(episodeMatch[2], 10),
      };
    }

    // Fallback: just extract any number as episode
    const numberMatch = /(.+?)\s*(\d+)\s*$/i.exec(nameWithoutExt);
    if (numberMatch) {
      return {
        title: numberMatch[1].trim().replace(/[[\]]/g, ''),
        season: 1,
        episode: parseInt(numberMatch[2], 10),
      };
    }

    return { title: '', season: 1, episode: 0 };
  }
}
