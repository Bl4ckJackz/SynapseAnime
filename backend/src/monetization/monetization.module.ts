import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { Subscription } from '../entities/subscription.entity';
import { Payment } from '../entities/payment.entity';
import { Ad, AdImpression } from '../entities/ad.entity';
import { News } from '../entities/news.entity';
import { SubscriptionService } from '../services/subscription.service';
import { PaymentService } from '../services/payment.service';
import { AdService } from '../services/ad.service';
import { NewsService } from '../services/news.service';
import { MangaDexService } from '../services/mangadex-api.service';
import { AnimeStreamingService } from '../services/anime-streaming.service';
import { AdInsertionService } from '../services/ad-insertion.service';
import { User } from '../entities/user.entity';
import { Manga } from '../entities/manga.entity';
import { Chapter } from '../entities/chapter.entity';
import { Anime } from '../entities/anime.entity';
import { Episode } from '../entities/episode.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      Subscription,
      Payment,
      Ad,
      AdImpression,
      News,
      Manga,
      Chapter,
      Anime,
      Episode,
    ]),
    ConfigModule,
  ],
  providers: [
    SubscriptionService,
    PaymentService,
    AdService,
    NewsService,
    MangaDexService,
    AnimeStreamingService,
    AdInsertionService,
  ],
  exports: [
    SubscriptionService,
    PaymentService,
    AdService,
    NewsService,
    MangaDexService,
    AnimeStreamingService,
    AdInsertionService,
  ],
})
export class MonetizationModule {}
