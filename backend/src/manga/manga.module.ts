import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { Manga } from '../entities/manga.entity';
import { Chapter } from '../entities/chapter.entity';
import { Anime } from '../entities/anime.entity';
import { Episode } from '../entities/episode.entity';
import { MangaService } from '../services/manga.service';
import { MangaDexService } from '../services/mangadex-api.service';
import { AnimeStreamingService } from '../services/anime-streaming.service';
import { MangaDexController } from './mangadex.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Manga, Chapter, Anime, Episode]),
    HttpModule,
  ],
  controllers: [MangaDexController],
  providers: [MangaService, MangaDexService, AnimeStreamingService],
  exports: [MangaService, MangaDexService],
})
export class MangaModule {}
