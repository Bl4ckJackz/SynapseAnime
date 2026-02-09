import { Injectable, Inject, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LlmAdapter, UserContext } from './adapters/llm.adapter';
import { Anime } from '../entities/anime.entity';
import { UserPreference } from '../entities/user-preference.entity';
import { WatchHistory } from '../entities/watch-history.entity';
import { User } from '../entities/user.entity';
import { RecommendDto } from './dto/recommend.dto';
import { Cron, CronExpression } from '@nestjs/schedule';
import { FcmService } from '../notifications/fcm.service';

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);

  constructor(
    @Inject('LLM_ADAPTER')
    private readonly llmAdapter: LlmAdapter,
    @InjectRepository(Anime)
    private animeRepository: Repository<Anime>,
    @InjectRepository(UserPreference)
    private preferenceRepository: Repository<UserPreference>,
    @InjectRepository(WatchHistory)
    private watchHistoryRepository: Repository<WatchHistory>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private readonly fcmService: FcmService,
  ) { }

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

  async chat(userId: string, messages: any[]) {
    this.logger.log(`Handling chat for user ${userId}`);
    const context = await this.buildUserContext(userId);
    this.logger.log(`Built context for user ${userId}: ${JSON.stringify(context)}`);
    return this.llmAdapter.chat({
      messages,
      context,
    });
  }

  private async buildUserContext(userId: string): Promise<UserContext> {
    const preference = await this.preferenceRepository.findOne({
      where: { userId },
    });

    const watchHistory = await this.watchHistoryRepository.find({
      where: { userId },
      relations: ['episode', 'episode.anime'],
      order: { updatedAt: 'DESC' },
      take: 20,
    });

    const watchedAnimeIds = [
      ...new Set(watchHistory.map((h) => h.episode?.anime?.id).filter(Boolean)),
    ] as string[];

    return {
      userId,
      preferredGenres: preference?.preferredGenres ?? [],
      preferredLanguages: preference?.preferredLanguages ?? [],
      watchedAnimeIds,
    };
  }

  // Run every day at 10 AM
  @Cron(CronExpression.EVERY_DAY_AT_10AM)
  async checkUserTrends() {
    this.logger.log('Running daily user trends analysis...');

    // Find users with FCM tokens (active users)
    const users = await this.userRepository.find();

    for (const user of users) {
      if (!user.fcmToken) continue;

      try {
        const context = await this.buildUserContext(user.id);
        if (context.watchedAnimeIds.length === 0 && context.preferredGenres.length === 0) continue;

        // Ask LLM for news/trends
        const prompt = `
          Based on this user's preferences:
          - Genres: ${context.preferredGenres.join(', ')}
          - Recently watched: ${context.watchedAnimeIds.slice(0, 3).join(', ')}
          
          Is there any specific trend, upcoming anime news, or interesting fact relevant to them?
          If yes, provide a short, catchy notification title and body (max 2 sentences).
          If nothing interesting, reply with "NO_NEWS".
          
          Format: JSON { "title": "...", "body": "..." }
        `;

        const response = await this.llmAdapter.chat({
          messages: [{ role: 'user', content: prompt }],
          context,
        });

        if (response.includes('NO_NEWS')) continue;

        // Parse JSON response (simple heuristic)
        const jsonMatch = response.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          const notification = JSON.parse(jsonMatch[0]);
          await this.fcmService.sendToDevice(user.fcmToken, {
            title: notification.title || 'Novità Anime per te! 🌟',
            body: notification.body || 'Scopri le ultime tendenze basate sui tuoi gusti.',
            data: { type: 'ai_recommendation' },
          });
          this.logger.log(`Sent AI trend notification to user ${user.id}`);
        }
      } catch (error) {
        this.logger.error(`Failed to generate trend for user ${user.id}`, error);
        // Continue to next user
      }
    }
  }
}

