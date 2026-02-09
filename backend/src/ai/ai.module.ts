import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { Anime } from '../entities/anime.entity';
import { UserPreference } from '../entities/user-preference.entity';
import { WatchHistory } from '../entities/watch-history.entity';
import { ConfigModule } from '@nestjs/config';
import { PerplexityAdapter } from './adapters/perplexity.adapter';
import { NotificationsModule } from '../notifications/notifications.module';
import { User } from '../entities/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Anime, UserPreference, WatchHistory, User]),
    ConfigModule,
    NotificationsModule,
  ],
  controllers: [AiController],
  providers: [
    AiService,
    {
      provide: 'LLM_ADAPTER',
      useClass: PerplexityAdapter,
    },
  ],
  exports: [AiService],
})
export class AiModule { }
