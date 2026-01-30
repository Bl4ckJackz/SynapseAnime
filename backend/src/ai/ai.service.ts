import { Injectable, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LlmAdapter, UserContext } from './adapters/llm.adapter';
import { Anime } from '../entities/anime.entity';
import { UserPreference } from '../entities/user-preference.entity';
import { WatchHistory } from '../entities/watch-history.entity';
import { RecommendDto } from './dto/recommend.dto';

@Injectable()
export class AiService {
  constructor(
    @Inject('LLM_ADAPTER')
    private readonly llmAdapter: LlmAdapter,
    @InjectRepository(Anime)
    private animeRepository: Repository<Anime>,
    @InjectRepository(UserPreference)
    private preferenceRepository: Repository<UserPreference>,
    @InjectRepository(WatchHistory)
    private watchHistoryRepository: Repository<WatchHistory>,
  ) {}

  async recommend(userId: string, dto: RecommendDto) {
    // Get user preferences
    const preference = await this.preferenceRepository.findOne({
      where: { userId },
    });

    // Get watch history to exclude and for context
    const watchHistory = await this.watchHistoryRepository.find({
      where: { userId },
      relations: ['episode', 'episode.anime'],
    });

    const watchedAnimeIds = [
      ...new Set(watchHistory.map((h) => h.episode?.anime?.id).filter(Boolean)),
    ] as string[];

    // Build user context
    const context: UserContext = {
      userId,
      preferredGenres: preference?.preferredGenres ?? [],
      preferredLanguages: preference?.preferredLanguages ?? [],
      watchedAnimeIds,
    };

    // Get all available anime
    const availableAnime = await this.animeRepository.find();

    // Get recommendations from LLM adapter
    const response = await this.llmAdapter.recommend(
      { message: dto.message, context },
      availableAnime,
    );

    // Fetch full anime details for response
    const recommendedAnime = await this.animeRepository.findByIds(
      response.recommendedAnimeIds,
    );

    return {
      message: response.message,
      recommendations: recommendedAnime,
    };
  }
}
