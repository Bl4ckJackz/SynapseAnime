import {
  Injectable,
  NotFoundException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Download, DownloadStatus } from '../entities/download.entity';
import { DownloadSettings } from '../entities/download-settings.entity';
import { AnimeUnitySource } from '../anime/sources/animeunity.source';
import { HiAnimeSource } from '../anime/sources/hianime.source';
import * as path from 'path';
import * as fs from 'fs';
import axios from 'axios';
import { HttpService } from '@nestjs/axios';
import { LibraryService } from '../library/library.service';
import { DownloadGateway } from './download.gateway';

const ffmpeg = require('fluent-ffmpeg');

const ffmpegPath = require('ffmpeg-static');

const ffprobePath = require('ffprobe-static');

@Injectable()
export class DownloadService implements OnModuleInit {
  private readonly logger = new Logger(DownloadService.name);
  private isProcessing = false;
  private readonly defaultDownloadPath: string;
  private activeDownloads = new Map<string, () => void>();

  constructor(
    @InjectRepository(Download)
    private downloadRepository: Repository<Download>,
    @InjectRepository(DownloadSettings)
    private settingsRepository: Repository<DownloadSettings>,
    private readonly httpService: HttpService,
    private readonly animeUnitySource: AnimeUnitySource,
    private readonly hiAnimeSource: HiAnimeSource,
    private readonly libraryService: LibraryService,
    private readonly downloadGateway: DownloadGateway,
  ) {
    if (ffmpegPath) {
      ffmpeg.setFfmpegPath(ffmpegPath);

      if (ffprobePath && ffprobePath.path) {
        ffmpeg.setFfprobePath(ffprobePath.path);
        this.logger.log(`FFprobe path set to: ${ffprobePath.path}`);
      }
      this.logger.log(`FFmpeg path set to: ${ffmpegPath}`);
    } else {
      this.logger.error('FFmpeg static binary not found!');
    }

    this.defaultDownloadPath = path.join(process.cwd(), 'video_library');
  }

  onModuleInit() {
    this.startQueueProcessor();
    // Run migration to move files from old 'downloads' folder to 'video_library'
    this.migrateDownloadsFolder();
  }

  // ========== MIGRATION ==========

  private async migrateDownloadsFolder() {
    const oldPath = path.join(process.cwd(), 'downloads');
    const newPath = this.defaultDownloadPath;

    if (fs.existsSync(oldPath) && fs.existsSync(newPath)) {
      this.logger.log(`Migrating files from ${oldPath} to ${newPath}...`);
      try {
        const files = await fs.promises.readdir(oldPath);
        for (const file of files) {
          const oldFilePath = path.join(oldPath, file);
          const newFilePath = path.join(newPath, file);

          // Skip if destination already exists
          if (fs.existsSync(newFilePath)) {
            this.logger.warn(`File ${file} already exists in new location, skipping migration.`);
            continue;
          }

          await fs.promises.rename(oldFilePath, newFilePath);
          this.logger.log(`Moved ${file} to ${newPath}`);
        }

        // Try to remove the old folder if empty
        const remainingFiles = await fs.promises.readdir(oldPath);
        if (remainingFiles.length === 0) {
          await fs.promises.rmdir(oldPath);
          this.logger.log(`Removed empty folder: ${oldPath}`);
        }
      } catch (error) {
        this.logger.error('Failed to migrate downloads folder', error);
      }
    }
  }

  // ========== SETTINGS ==========

  async getSettings(userId: string): Promise<DownloadSettings> {
    let settings = await this.settingsRepository.findOne({ where: { userId } });
    if (!settings) {
      settings = this.settingsRepository.create({
        userId,
        downloadPath: this.defaultDownloadPath,
        useServerFolder: true,
        serverFolderPath: this.defaultDownloadPath,
      });
      await this.settingsRepository.save(settings);
    } else {
      // Auto-fix: If settings still point to "downloads" or are missing, force "video_library"
      let changed = false;

      // Ensure we are using the video_library path
      const videoLibraryPath = path.normalize(this.defaultDownloadPath);
      const currentDownloadPath = settings.downloadPath ? path.normalize(settings.downloadPath) : '';
      const currentServerPath = settings.serverFolderPath ? path.normalize(settings.serverFolderPath) : '';

      this.logger.log(`[getSettings] Checking paths for user ${userId}`);
      this.logger.log(`[getSettings] Expected: ${videoLibraryPath}`);
      this.logger.log(`[getSettings] Current Download: ${currentDownloadPath}`);
      this.logger.log(`[getSettings] Current Server: ${currentServerPath}`);

      if (currentDownloadPath !== videoLibraryPath) {
        this.logger.log(`[getSettings] Mismatch detected in downloadPath. Updating...`);
        settings.downloadPath = videoLibraryPath;
        changed = true;
      }

      if (currentServerPath !== videoLibraryPath) {
        this.logger.log(`[getSettings] Mismatch detected in serverFolderPath. Updating...`);
        settings.serverFolderPath = videoLibraryPath;
        changed = true;
      }

      if (changed) {
        this.logger.log(`Enforcing video_library path for user ${userId}`);
        await this.settingsRepository.save(settings);
      }
    }
    return settings;
  }

  async updateSettings(
    userId: string,
    updates: Partial<DownloadSettings>,
  ): Promise<DownloadSettings> {
    let settings = await this.getSettings(userId);
    settings = { ...settings, ...updates };
    return this.settingsRepository.save(settings);
  }

  // ========== QUEUE MANAGEMENT ==========

  async clearDownloads(): Promise<void> {
    await this.downloadRepository.clear();
    this.logger.log('Download repository cleared');
  }

  async queueSeasonDownload(
    userId: string,
    animeId: string,
    season: number,
    source?: string,
    title?: string,
  ): Promise<Download[]> {
    this.logger.log(
      `Queueing season download: animeId=${animeId}, season=${season}, source=${source}, title=${title}`,
    );

    // For AnimeUnity, always use it as the source
    const activeSource =
      source === 'hianime' ? this.hiAnimeSource : this.animeUnitySource;
    const sourceName = source === 'hianime' ? 'hianime' : 'animeunity';

    let anime: any = null;
    let resolvedAnimeId = animeId;

    // First, try to get anime by ID directly
    anime = await activeSource.getAnimeById(animeId);

    // If ID lookup failed and we have a title, search by title
    if (!anime && title && sourceName === 'animeunity') {
      this.logger.log(`ID lookup failed, searching by title: ${title}`);
      const searchResults = await activeSource.getAnimeList({
        search: title,
        page: 1,
      });

      if (searchResults.data && searchResults.data.length > 0) {
        // Use the first result's ID
        const firstResult = searchResults.data[0];
        this.logger.log(
          `Found anime via search: ${firstResult.title} (ID: ${firstResult.id})`,
        );
        resolvedAnimeId = firstResult.id;
        anime = await activeSource.getAnimeById(resolvedAnimeId);
      }
    }

    if (!anime) {
      this.logger.error(
        `Anime with ID ${animeId} not found from ${sourceName}`,
      );
      throw new NotFoundException(`Anime with ID ${animeId} not found`);
    }

    // Get episodes using the resolved anime ID
    const episodes = await activeSource.getEpisodes(resolvedAnimeId);
    this.logger.log(
      `Found ${episodes.length} episodes for anime ${anime.title}`,
    );

    // Filter by season if applicable
    const seasonEpisodes = episodes.filter((ep) => {
      // If episodes have season info, filter by it
      if ((ep as any).season !== undefined) {
        return (ep as any).season === season;
      }
      // Otherwise, include all for season 1 request
      return season === 1;
    });

    if (seasonEpisodes.length === 0) {
      throw new NotFoundException(`No episodes found for season ${season}`);
    }

    this.logger.log(
      `Queueing ${seasonEpisodes.length} episodes from season ${season}`,
    );

    // Create download entries for each episode
    const downloads: Download[] = [];
    for (const episode of seasonEpisodes) {
      // Check if already queued/downloading
      const existing = await this.downloadRepository.findOne({
        where: {
          userId,
          animeId,
          episodeId: episode.id,
          status: In([DownloadStatus.PENDING, DownloadStatus.DOWNLOADING]),
        },
      });

      if (existing) {
        downloads.push(existing);
        continue;
      }

      const download = this.downloadRepository.create({
        userId,
        animeId,
        animeName: anime.title,
        episodeId: episode.id,
        episodeNumber: episode.number,
        episodeTitle: episode.title,
        status: DownloadStatus.PENDING,
        source: sourceName,
        thumbnailUrl: episode.thumbnail,
      });

      await this.downloadRepository.save(download);
      downloads.push(download);
    }

    // Trigger queue processing
    void this.processQueue();

    return downloads;
  }

  async queueEpisodeDownload(
    userId: string,
    animeId: string,
    episodeId: string,
    source?: string,
  ): Promise<Download> {
    // Determine which source to use based on the animeId format or explicit source
    const isHiAnime =
      source === 'hianime' || animeId.includes('-') || animeId.includes('?');
    const activeSource = isHiAnime ? this.hiAnimeSource : this.animeUnitySource;
    const sourceName = isHiAnime ? 'hianime' : 'animeunity';

    // Get anime info directly from the source
    const anime = await activeSource.getAnimeById(animeId);
    if (!anime) {
      throw new NotFoundException(`Anime with ID ${animeId} not found`);
    }

    // Get episode info directly from the source
    const episodes = await activeSource.getEpisodes(animeId);
    const episode = episodes.find((ep) => ep.id === episodeId);
    if (!episode) {
      throw new NotFoundException(`Episode with ID ${episodeId} not found`);
    }

    // Check if already queued/downloading
    const existing = await this.downloadRepository.findOne({
      where: {
        userId,
        animeId,
        episodeId,
        status: In([DownloadStatus.PENDING, DownloadStatus.DOWNLOADING]),
      },
    });

    if (existing) {
      return existing;
    }

    const download = this.downloadRepository.create({
      userId,
      animeId,
      animeName: anime.title,
      episodeId,
      episodeNumber: episode.number,
      episodeTitle: episode.title,
      status: DownloadStatus.PENDING,
      source: sourceName,
      thumbnailUrl: episode.thumbnail,
    });

    await this.downloadRepository.save(download);

    // Trigger queue processing
    void this.processQueue();

    return download;
  }

  // ========== DIRECT URL DOWNLOAD ==========

  async queueUrlDownload(
    userId: string,
    url: string,
    animeName: string,
    episodeNumber: number,
    episodeTitle?: string,
  ): Promise<Download> {
    // Validate URL protocol
    try {
      const parsed = new URL(url);
      if (!['http:', 'https:'].includes(parsed.protocol)) {
        throw new Error('Only HTTP/HTTPS URLs are allowed');
      }
    } catch {
      throw new Error('Invalid download URL');
    }

    this.logger.log(
      `Queueing direct URL download: ${animeName} - Episode ${episodeNumber}`,
    );

    // Check if already downloading
    const existing = await this.downloadRepository.findOne({
      where: {
        userId,
        streamUrl: url,
        status: In([DownloadStatus.PENDING, DownloadStatus.DOWNLOADING]),
      },
    });

    if (existing) {
      this.logger.log('Download already in queue');
      return existing;
    }

    const download = this.downloadRepository.create({
      userId,
      animeId: 'direct-url',
      animeName,
      episodeId: `ep-${episodeNumber}`,
      episodeNumber,
      episodeTitle: episodeTitle || `Episode ${episodeNumber}`,
      status: DownloadStatus.PENDING,
      source: 'direct',
      streamUrl: url, // Already set the stream URL!
    });

    await this.downloadRepository.save(download);

    // Trigger queue processing
    void this.processQueue();

    return download;
  }

  async getDownloadQueue(userId: string): Promise<Download[]> {
    return this.downloadRepository.find({
      where: {
        userId,
        status: In([DownloadStatus.PENDING, DownloadStatus.DOWNLOADING]),
      },
      order: { createdAt: 'ASC' },
    });
  }

  async getDownloadHistory(userId: string, limit = 50): Promise<Download[]> {
    return this.downloadRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }

  async cancelDownload(userId: string, downloadId: string): Promise<void> {
    const download = await this.downloadRepository.findOne({
      where: { id: downloadId, userId },
    });

    if (!download) {
      throw new NotFoundException(`Download with ID ${downloadId} not found`);
    }

    if (download.status === DownloadStatus.COMPLETED) {
      throw new Error('Cannot cancel a completed download');
    }

    // Cancel active process if exists
    if (this.activeDownloads.has(downloadId)) {
      this.logger.log(`Cancelling active download process for ${downloadId}`);
      this.activeDownloads.get(downloadId)?.();
      this.activeDownloads.delete(downloadId);
      // Give it a moment to release file locks
      await new Promise((resolve) => setTimeout(resolve, 500));
    }

    download.status = DownloadStatus.CANCELLED;
    await this.downloadRepository.save(download);
    this.downloadGateway.notifyDownloadProgress(download.userId, download);
  }

  async deleteDownload(userId: string, downloadId: string): Promise<void> {
    const download = await this.downloadRepository.findOne({
      where: { id: downloadId, userId },
    });

    if (!download) {
      throw new NotFoundException(`Download with ID ${downloadId} not found`);
    }

    // Cancel active process if running
    if (this.activeDownloads.has(downloadId)) {
      this.logger.log(
        `Cancelling active download process for ${downloadId} before deletion`,
      );
      this.activeDownloads.get(downloadId)?.();
      this.activeDownloads.delete(downloadId);
      // Give it a moment to release file locks
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    // Delete file if exists
    if (download.filePath && fs.existsSync(download.filePath)) {
      try {
        fs.unlinkSync(download.filePath);
      } catch (e) {
        this.logger.warn(`Failed to delete file ${download.filePath}: ${e.message}`);
      }
    }

    // Also try to delete thumbnail
    if (download.thumbnailPath) {
      const thumbPath = path.join(this.defaultDownloadPath, download.thumbnailPath);
      if (fs.existsSync(thumbPath)) {
        try {
          fs.unlinkSync(thumbPath);
        } catch (e) {
          // ignore
        }
      }
    }

    await this.downloadRepository.remove(download);
  }

  // ========== QUEUE PROCESSOR ==========

  private startQueueProcessor() {
    // Reset any downloads that were stuck in 'downloading' state due to server restart
    this.resetStuckDownloads().then(() => {
      // Process queue once on startup to handle pending items
      void this.processQueue();
    });
  }

  private async resetStuckDownloads() {
    await this.downloadRepository.update(
      { status: DownloadStatus.DOWNLOADING },
      { status: DownloadStatus.PENDING, progress: 0 },
    );
    this.logger.log('Reset stuck downloads to PENDING');
  }

  private async processQueue() {
    if (this.isProcessing) return;

    this.isProcessing = true;

    try {
      // Polling log removed. Processing triggered by new downloads or startup.
      // Get next pending download
      const nextDownload = await this.downloadRepository.findOne({
        where: { status: DownloadStatus.PENDING },
        order: { createdAt: 'ASC' },
      });

      if (!nextDownload) {
        // this.logger.log('No pending downloads found');
        this.isProcessing = false;
        return;
      }

      this.logger.log(`Found pending download: ${nextDownload.id}`);
      await this.downloadEpisode(nextDownload);
    } catch (error) {
      this.logger.error('Queue processing error:', error);
    } finally {
      this.isProcessing = false;
    }
  }

  private async downloadEpisode(download: Download): Promise<void> {
    this.logger.log(
      `Starting processing for download ${download.id}: ${download.animeName} - Episode ${download.episodeNumber}`,
    );

    // Update status to downloading
    download.status = DownloadStatus.DOWNLOADING;
    download.progress = 0;
    await this.downloadRepository.save(download);
    this.downloadGateway.notifyDownloadProgress(download.userId, download);

    try {
      // Get stream URL
      let streamUrl: string;
      if (download.source === 'direct') {
        streamUrl = download.streamUrl;
      } else if (download.source === 'hianime') {
        streamUrl = await this.hiAnimeSource.getStreamUrl(download.episodeId);
      } else {
        streamUrl = await this.animeUnitySource.getStreamUrl(
          download.episodeId,
        );
      }

      if (!streamUrl) {
        throw new Error('Failed to get stream URL');
      }

      download.streamUrl = streamUrl;

      // Get settings for download path
      const settings = await this.getSettings(download.userId);
      const basePath = settings.useServerFolder
        ? settings.serverFolderPath || this.defaultDownloadPath
        : settings.downloadPath || this.defaultDownloadPath;

      // Create anime folder - sanitize name for filesystem
      const sanitizedAnimeName = this.sanitizeFileName(download.animeName);
      const animeFolder = path.join(basePath, sanitizedAnimeName);

      // Ensure the resolved path stays within basePath (prevent path traversal)
      const resolvedFolder = path.resolve(animeFolder);
      const resolvedBase = path.resolve(basePath);
      if (!resolvedFolder.startsWith(resolvedBase)) {
        throw new Error('Invalid download path detected');
      }

      if (!fs.existsSync(animeFolder)) {
        fs.mkdirSync(animeFolder, { recursive: true });
      }

      this.logger.log(`Saving to folder: ${animeFolder}`);

      // Generate filename: animename-n-episodio
      const fileName = `${sanitizedAnimeName}-${download.episodeNumber}.mp4`;
      const filePath = path.join(animeFolder, fileName);

      download.fileName = fileName;
      download.filePath = filePath;
      this.logger.log(`Full file path: ${filePath}`);
      await this.downloadRepository.save(download);

      // Download thumbnail if available
      if (download.thumbnailUrl) {
        try {
          const thumbnailExt =
            path.extname(download.thumbnailUrl).split('?')[0] || '.jpg';
          // Use sync version to avoid async issues in loop? No, await is fine.
          const thumbnailName = `${fileName.replace('.mp4', '')}${thumbnailExt}`;
          const thumbnailPath = path.join(animeFolder, thumbnailName);

          this.logger.log(`Downloading thumbnail to: ${thumbnailPath}`);
          await this.downloadThumbnail(download.thumbnailUrl, thumbnailPath);
          // Store relative path for serving
          download.thumbnailPath = path
            .relative(this.defaultDownloadPath, thumbnailPath)
            .replace(/\\/g, '/');
          await this.downloadRepository.save(download);
        } catch (e) {
          this.logger.warn(`Failed to download thumbnail: ${e.message}`);
        }
      }

      // Detect HLS stream
      const isHls =
        streamUrl.includes('.m3u8') || streamUrl.includes('master.m3u8');

      // Download the file
      this.logger.log(`HLS: ${isHls}, URL: ${streamUrl}`);

      if (isHls) {
        // HLS stream - Use ffmpeg to download and convert to MP4
        this.logger.log(`Starting HLS download for ${fileName} via FFmpeg`);
        await this.downloadHlsStream(streamUrl, filePath, download);
      } else {
        // Direct MP4 download
        await this.downloadFile(streamUrl, filePath, download);
      }

      // Cleanup tracker
      this.activeDownloads.delete(download.id);

      // Mark as completed
      download.status = DownloadStatus.COMPLETED;
      download.progress = 100;
      download.completedAt = new Date();
      await this.downloadRepository.save(download);
      this.downloadGateway.notifyDownloadProgress(download.userId, download);

      this.logger.log(
        `Download completed: ${download.animeName} - Episode ${download.episodeNumber}`,
      );

      // Organize library after download
      try {
        await this.libraryService.organizeLibrary();
      } catch (orgError) {
        this.logger.warn('Failed to organize library after download:', orgError);
      }
    } catch (error) {
      this.activeDownloads.delete(download.id);

      // If cancelled, don't mark as failed
      if (error.message === 'Download cancelled') {
        this.logger.log(`Download cancelled: ${download.id}`);
        return; // Already handled in cancelDownload
      }

      this.logger.error(
        `Download failed for ${download.animeName} - Episode ${download.episodeNumber}:`,
        error,
      );

      download.status = DownloadStatus.FAILED;
      download.errorMessage = error.message;
      await this.downloadRepository.save(download);
      this.downloadGateway.notifyDownloadProgress(download.userId, download);
    }
  }

  private async downloadFile(
    url: string,
    filePath: string,
    download: Download,
  ): Promise<void> {
    const response = await axios({
      method: 'GET',
      url,
      responseType: 'stream',
      timeout: 300000, // 5 minutes timeout
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    });

    const totalLength = parseInt(response.headers['content-length'] || '0', 10);
    this.logger.log(`Content-Length: ${totalLength}`);
    let downloadedLength = 0;

    const writer = fs.createWriteStream(filePath);

    return new Promise((resolve, reject) => {
      // Allow cancellation
      this.activeDownloads.set(download.id, () => {
        response.data.destroy();
        writer.destroy();
        reject(new Error('Download cancelled'));
      });

      response.data.on('data', async (chunk: Buffer) => {
        downloadedLength += chunk.length;
        if (totalLength > 0) {
          const progress = Math.round((downloadedLength / totalLength) * 100);
          if (progress !== download.progress && progress % 10 === 0) {
            download.progress = progress;
            // Don't await strictly to avoid blocking processing significantly
            this.downloadRepository.save(download).catch(() => { });
            this.downloadGateway.notifyDownloadProgress(
              download.userId,
              download,
            );
          }
        }
      });

      response.data.pipe(writer);

      writer.on('finish', () => resolve());
      writer.on('error', reject);
      response.data.on('error', reject);
    });
  }

  private async downloadHlsStream(
    url: string,
    filePath: string,
    download: Download,
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      // Probe to get duration for progress calculation
      ffmpeg.ffprobe(url, (err: any, metadata: any) => {
        let duration = 0;
        if (!err && metadata && metadata.format && metadata.format.duration) {
          duration = parseFloat(metadata.format.duration);
          this.logger.log(`Stream duration: ${duration}s`);
        }

        const command = ffmpeg(url)
          // Re-encode to ensure compatible MP4 (handling HLS adaptive bitrate issues)
          // .outputOptions('-c copy')
          .outputOptions('-c:v libx264')
          .outputOptions('-preset fast')
          .outputOptions('-c:a aac')
          .output(filePath)
          .on('start', (commandLine: string) => {
            this.logger.log(`Spawned Ffmpeg with command: ${commandLine}`);
          })
          .on('progress', (progress: any) => {
            let percentage = 0;
            if (progress.percent) {
              percentage = Math.round(progress.percent);
            } else if (duration > 0 && progress.timemark) {
              // Calculate percentage from timemark
              // timemark format: HH:MM:SS.mm
              const parts = progress.timemark.split(':');
              const seconds =
                parseInt(parts[0]) * 3600 +
                parseInt(parts[1]) * 60 +
                parseFloat(parts[2]);
              percentage = Math.round((seconds / duration) * 100);
            }

            if (percentage > 0 && percentage !== download.progress) {
              download.progress = percentage;
              this.downloadGateway.notifyDownloadProgress(
                download.userId,
                download,
              );
            }
          })
          .on('error', (err: any) => {
            if (err.message.includes('SIGKILL')) {
              // Determine if explicitly cancelled
              reject(new Error('Download cancelled'));
            } else {
              this.logger.error('An error occurred: ' + err.message);
              reject(new Error(err.message));
            }
          })
          .on('end', async () => {
            this.logger.log('Processing finished !');
            download.progress = 100;
            // await this.downloadRepository.save(download); // Ensure 100% saved
            resolve();
          });

        // Allow cancellation
        this.activeDownloads.set(download.id, () => {
          command.kill('SIGKILL');
          reject(new Error('Download cancelled'));
        });

        command.run();
      });

      // Start a periodic saver for progress to avoid DB spam
      const progressSaver = setInterval(async () => {
        if (download.status === DownloadStatus.DOWNLOADING) {
          try {
            await this.downloadRepository.save(download);
          } catch (e) {
            // ignore
          }
        } else {
          clearInterval(progressSaver);
        }
      }, 2000); // Save every 2 seconds
    });
  }

  private async downloadThumbnail(
    url: string,
    filePath: string,
  ): Promise<void> {
    const writer = fs.createWriteStream(filePath);
    const response = await axios({
      url,
      method: 'GET',
      responseType: 'stream',
    });

    response.data.pipe(writer);

    return new Promise((resolve, reject) => {
      writer.on('finish', resolve);
      writer.on('error', reject);
    });
  }

  private sanitizeFileName(name: string): string {
    // Remove invalid filesystem characters and prevent path traversal
    return name
      .replace(/\.\./g, '') // Prevent directory traversal
      .replace(/[<>:"/\\|?*]/g, '')
      .replace(/^\.+/, '') // Remove leading dots
      .replace(/\s+/g, '_')
      .replace(/_{2,}/g, '_') // Collapse multiple underscores
      .substring(0, 100) // Limit length
      || 'unnamed';
  }
}
