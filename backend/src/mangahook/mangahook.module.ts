import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MangaHookService } from './mangahook.service';
import { MangaHookController } from './mangahook.controller';
import { MangaModule } from '../manga/manga.module';

@Module({
  imports: [ConfigModule, MangaModule],
  controllers: [MangaHookController],
  providers: [MangaHookService],
  exports: [MangaHookService],
})
export class MangaHookModule {}
