import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';
import { UserPreference } from '../entities/user-preference.entity';
import { Watchlist } from '../entities/watchlist.entity';
import { WatchHistory } from '../entities/watch-history.entity';
import { Episode } from '../entities/episode.entity';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import { UpdateProgressDto } from './dto/update-progress.dto';

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
    private episodeRepository: Repository<Episode>,
  ) {}

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
      relations: ['anime'],
      order: { addedAt: 'DESC' },
    });
  }

  async addToWatchlist(userId: string, animeId: string) {
    const existing = await this.watchlistRepository.findOne({
      where: { userId, animeId },
    });

    if (existing) {
      return existing;
    }

    const entry = this.watchlistRepository.create({ userId, animeId });
    return this.watchlistRepository.save(entry);
  }

  async removeFromWatchlist(userId: string, animeId: string) {
    const result = await this.watchlistRepository.delete({ userId, animeId });
    return { deleted: (result.affected ?? 0) > 0 };
  }

  async isInWatchlist(userId: string, animeId: string) {
    const entry = await this.watchlistRepository.findOne({
      where: { userId, animeId },
    });
    return { inWatchlist: !!entry };
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

  async updateProgress(userId: string, dto: UpdateProgressDto) {
    // Verify episode exists
    const episode = await this.episodeRepository.findOne({
      where: { id: dto.episodeId },
    });
    if (!episode) {
      throw new NotFoundException('Episode not found');
    }

    let history = await this.watchHistoryRepository.findOne({
      where: { userId, episodeId: dto.episodeId },
    });

    if (!history) {
      history = this.watchHistoryRepository.create({
        userId,
        episodeId: dto.episodeId,
      });
    }

    history.progressSeconds = dto.progressSeconds;

    // Mark as completed if progress is close to duration
    if (episode.duration > 0 && dto.progressSeconds >= episode.duration * 0.9) {
      history.completed = true;
    }

    return this.watchHistoryRepository.save(history);
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
}
