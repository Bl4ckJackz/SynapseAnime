import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as fs from 'fs';
import * as path from 'path';
import {
  AnimeSource,
  AnimeFilters,
  PaginatedResult,
} from './anime-source.interface';
import { Anime, AnimeStatus } from '../../entities/anime.entity';
import { Episode } from '../../entities/episode.entity';

@Injectable()
export class LocalFileSource implements AnimeSource {
  readonly id = 'local_files';
  readonly name = 'Local Server Files';
  readonly description = 'Video files from local server directory';
  readonly hasDirectStream = true;
  private readonly logger = new Logger(LocalFileSource.name);

  private basePath: string;
  private animeCache: Map<string, Anime> = new Map();
  private episodeCache: Map<string, Episode[]> = new Map();

  constructor(private configService: ConfigService) {
    this.basePath =
      this.configService.get<string>('LOCAL_ANIME_PATH') || './video_library';
    this.refreshLibrary();
  }

  // Simple method to refresh cache (in real app, use file watchers or cron)
  private refreshLibrary() {
    this.logger.log(`Scanning local library at: ${this.basePath}`);
    this.animeCache.clear();
    this.episodeCache.clear();

    if (!fs.existsSync(this.basePath)) {
      this.logger.warn(
        `Local path ${this.basePath} does not exist. Creating it.`,
      );
      try {
        fs.mkdirSync(this.basePath, { recursive: true });
      } catch (e) {
        this.logger.error(`Failed to create local path: ${e.message}`);
        return;
      }
    }

    try {
      const folders = fs
        .readdirSync(this.basePath, { withFileTypes: true })
        .filter((dirent) => dirent.isDirectory());

      for (const folder of folders) {
        this.processAnimeFolder(folder.name);
      }
      this.logger.log(`scanned ${this.animeCache.size} anime folders locally`);
    } catch (e) {
      this.logger.error(`Error scanning library: ${e.message}`);
    }
  }

  private processAnimeFolder(folderName: string) {
    const animeId = `local_${folderName.replace(/\s+/g, '_').toLowerCase()}`;
    const animePath = path.join(this.basePath, folderName);

    // Heuristic: folder name is title
    // Check for metadata.json for accurate info? For now just heuristic.

    // Scan for video files
    let videoFiles: string[] = [];
    try {
      videoFiles = fs.readdirSync(animePath).filter((file) => {
        const ext = path.extname(file).toLowerCase();
        return ['.mp4', '.mkv', '.webm'].includes(ext);
      });
    } catch (e) {
      return;
    }

    if (videoFiles.length === 0) return;

    // Create Anime Entity
    const anime = new Anime();
    anime.id = animeId;
    anime.title = folderName;
    anime.description = 'Local content from server';
    anime.genres = ['Local'];
    anime.status = AnimeStatus.COMPLETED;
    anime.releaseYear = new Date().getFullYear();
    anime.rating = 0;
    anime.totalEpisodes = videoFiles.length;
    anime.coverUrl = ''; // Could look for cover.jpg

    // Create Episodes
    const episodes: Episode[] = videoFiles.map((file, index) => {
      const ep = new Episode();
      ep.id = `${animeId}_ep_${index + 1}`;
      ep.animeId = animeId;
      ep.number = index + 1;
      ep.title = file; // simple name
      ep.duration = 0; // would need ffprobe to get duration
      ep.streamUrl = `/api/stream/local/${animeId}/${encodeURIComponent(file)}`; // Needs a stream controller
      // Hack: we need to serve these files.
      // We'll assume a new controller endpoint handles serving or just static serve.
      // For now, let's point to a placeholder logic endpoint.
      return ep;
    });

    this.animeCache.set(animeId, anime);
    this.episodeCache.set(animeId, episodes);
  }

  async getAnimeList(filters: AnimeFilters): Promise<PaginatedResult<Anime>> {
    // Basic in-memory filtering
    let results = Array.from(this.animeCache.values());

    if (filters.search) {
      const search = filters.search.toLowerCase();
      results = results.filter((a) => a.title.toLowerCase().includes(search));
    }

    const total = results.length;
    const page = filters.page || 1;
    const limit = filters.limit || 20;
    const start = (page - 1) * limit;

    const data = results.slice(start, start + limit);

    return {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getAnimeById(id: string): Promise<Anime | null> {
    const anime = this.animeCache.get(id);
    if (anime) {
      anime.episodes = this.episodeCache.get(id) || [];
    }
    return anime || null;
  }

  async getEpisodes(animeId: string): Promise<Episode[]> {
    return this.episodeCache.get(animeId) || [];
  }

  async getStreamUrl(episodeId: string): Promise<string> {
    // Finding episode to construct path
    for (const [animeId, episodes] of this.episodeCache.entries()) {
      const ep = episodes.find((e) => e.id === episodeId);
      if (ep) {
        // Return file path or ready-to-use URL
        // In this architecture, we return string.
        // It should be a URL accessible by frontend.
        // We need a backend endpoint that streams this file.
        // Let's assume we implement StreamController later.
        // Format: /stream?path=...

        // Actually, we stored the URL in the entity creation above.
        // But maybe we dynamic generate it here.
        return ep.streamUrl;
      }
    }
    return '';
  }

  // Helper to get real filesystem path for the streaming controller
  getVideoPath(animeId: string, filename: string): string | null {
    const anime = this.animeCache.get(animeId);
    if (!anime) return null;
    return path.join(this.basePath, anime.title, filename);
  }
}
