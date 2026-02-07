import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';
import { UserPreference } from '../entities/user-preference.entity';
import { Watchlist } from '../entities/watchlist.entity';
import { WatchHistory } from '../entities/watch-history.entity';
import { Episode } from '../entities/episode.entity';
import { Anime, AnimeStatus } from '../entities/anime.entity';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import { UpdateProgressDto } from './dto/update-progress.dto';
import { HistoryGateway } from './history.gateway';
import { AnimeService } from '../anime/anime.service';
import { MangaService } from '../services/manga.service';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(UserPreference)
    private preferenceRepository: Repository<UserPreference>,
    @InjectRepository(Watchlist)
    private watchlistRepository: Repository<Watchlist>,
    @InjectRepository(WatchHistory)
    private watchHistoryRepository: Repository<WatchHistory>,
    @InjectRepository(Episode)
    @InjectRepository(Episode)
    private episodeRepository: Repository<Episode>,
    private historyGateway: HistoryGateway,
    private animeService: AnimeService,
    private mangaService: MangaService,
  ) { }

  async updateProgress(userId: string, dto: UpdateProgressDto) {
    // Verify episode exists
    let episode = await this.episodeRepository.findOne({
      where: { id: dto.episodeId },
    });

    if (!episode) {
      // Lazy Creation logic
      if (dto.animeId && dto.episodeNumber) {
        // Check if anime exists
        let anime = await this.userRepository.manager.findOne(Anime, {
          where: { id: dto.animeId },
        });

        if (!anime) {
          // Create Anime
          anime = this.userRepository.manager.create(Anime, {
            id: dto.animeId,
            title: dto.animeTitle ?? 'Unknown Anime',
            coverUrl: dto.animeCover,
            totalEpisodes: dto.animeTotalEpisodes ?? 0,
            releaseYear: 0,
            rating: 0,
            popularity: 0,
            status: AnimeStatus.ONGOING,
            description: '',
            genres: [],
          });
          await this.userRepository.manager.save(anime);
        }

        // Create Episode
        episode = this.episodeRepository.create({
          id: dto.episodeId,
          animeId: dto.animeId,
          number: dto.episodeNumber,
          title: dto.episodeTitle ?? `Episode ${dto.episodeNumber}`,
          thumbnail: dto.episodeThumbnail,
          duration: dto.duration ?? 0,
          streamUrl: '',
        });
        await this.episodeRepository.save(episode);
      } else {
        throw new NotFoundException('Episode not found');
      }
    }

    // 1. Check for existing history for this ANIME
    let history = await this.watchHistoryRepository.findOne({
      where: {
        userId,
        episode: {
          animeId: episode.animeId,
        },
      },
      relations: ['episode'],
    });

    if (history) {
      // Update existing entry for this anime
      history.episodeId = dto.episodeId;
      history.episode = episode;
    } else {
      // No history for this anime. This is a new entry.
      // 2. Enforce Max 20 Limit
      const count = await this.watchHistoryRepository.count({
        where: { userId },
      });

      if (count >= 20) {
        // Find oldest updated entry
        const oldest = await this.watchHistoryRepository.findOne({
          where: { userId },
          order: { updatedAt: 'ASC' },
        });

        if (oldest) {
          await this.watchHistoryRepository.remove(oldest);
        }
      }

      // Create new
      history = this.watchHistoryRepository.create({
        userId,
        episodeId: dto.episodeId,
      });
    }

    // Update progress
    history.progressSeconds = dto.progressSeconds;
    history.completed = false;

    if (episode.duration > 0 && dto.progressSeconds >= episode.duration * 0.9) {
      history.completed = true;
    }

    const saved = await this.watchHistoryRepository.save(history);

    // Notify clients about the update
    this.historyGateway.notifyHistoryUpdate(userId);

    return saved;
  }

  async getEpisodeProgress(userId: string, episodeId: string) {
    const history = await this.watchHistoryRepository.findOne({
      where: { userId, episodeId },
    });
    return {
      progressSeconds: history?.progressSeconds ?? 0,
      completed: history?.completed ?? false,
    };
  }

  // --- Profile ---
  async getProfile(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['preference'],
    });
    if (!user) throw new NotFoundException('User not found');

    return {
      id: user.id,
      email: user.email,
      nickname: user.nickname,
      preference: user.preference,
    };
  }

  async updateProfile(userId: string, data: { nickname?: string }) {
    await this.userRepository.update(userId, data);
    return this.getProfile(userId);
  }

  // --- Preferences ---
  async updatePreferences(userId: string, dto: UpdatePreferencesDto) {
    let preference = await this.preferenceRepository.findOne({
      where: { userId },
    });

    if (!preference) {
      preference = this.preferenceRepository.create({ userId });
    }

    if (dto.preferredLanguages) {
      preference.preferredLanguages = dto.preferredLanguages;
    }
    if (dto.preferredGenres) {
      preference.preferredGenres = dto.preferredGenres;
    }

    return this.preferenceRepository.save(preference);
  }

  // --- Watchlist ---
  async getWatchlist(userId: string) {
    return this.watchlistRepository.find({
      where: { userId },
      relations: ['anime', 'manga'],
      order: { addedAt: 'DESC' },
    });
  }

  async addToWatchlist(userId: string, itemId: string, type: 'anime' | 'manga' = 'anime') {
    // Ensure item exists in local DB
    if (type === 'anime') {
      const anime = await this.animeService.findById(itemId);
      if (!anime) throw new NotFoundException('Anime not found');
    } else {
      const manga = await this.mangaService.getMangaById(itemId);
      if (!manga) throw new NotFoundException('Manga not found');
    }

    const where: any = { userId };
    if (type === 'anime') where.animeId = itemId;
    else where.mangaId = itemId;

    const exists = await this.watchlistRepository.findOne({ where });
    if (exists) return exists;

    const entry = this.watchlistRepository.create({
      userId,
      animeId: type === 'anime' ? itemId : null,
      mangaId: type === 'manga' ? itemId : null,
    } as any);
    return this.watchlistRepository.save(entry);
  }

  async removeFromWatchlist(userId: string, itemId: string, type: 'anime' | 'manga' = 'anime') {
    const where: any = { userId };
    if (type === 'anime') where.animeId = itemId;
    else where.mangaId = itemId;

    return this.watchlistRepository.delete(where);
  }

  async isInWatchlist(userId: string, itemId: string, type: 'anime' | 'manga' = 'anime') {
    const where: any = { userId };
    if (type === 'anime') where.animeId = itemId;
    else where.mangaId = itemId;

    const count = await this.watchlistRepository.count({ where });
    return { inWatchlist: count > 0 };
  }

  // --- Watch History ---
  async getWatchHistory(userId: string, limit = 20) {
    return this.watchHistoryRepository.find({
      where: { userId },
      relations: ['episode', 'episode.anime'],
      order: { updatedAt: 'DESC' },
      take: limit,
    });
  }

  async getContinueWatching(userId: string, limit = 10) {
    // Get episodes that are not completed
    return this.watchHistoryRepository.find({
      where: { userId, completed: false },
      relations: ['episode', 'episode.anime'],
      order: { updatedAt: 'DESC' },
      take: limit,
    });
  }
}
