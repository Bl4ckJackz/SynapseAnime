import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { MockLlmAdapter } from './adapters/mock-llm.adapter';
import { Anime } from '../entities/anime.entity';
import { UserPreference } from '../entities/user-preference.entity';
import { WatchHistory } from '../entities/watch-history.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Anime, UserPreference, WatchHistory])],
  controllers: [AiController],
  providers: [
    AiService,
    {
      provide: 'LLM_ADAPTER',
      useClass: MockLlmAdapter,
    },
  ],
  exports: [AiService],
})
export class AiModule {}
