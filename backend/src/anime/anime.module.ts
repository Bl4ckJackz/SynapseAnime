import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { AnimeController } from './anime.controller';
import { AnimeService } from './anime.service';
import { Anime } from '../entities/anime.entity';
import { Episode } from '../entities/episode.entity';
import { SourceManager } from './sources/source.manager';
import { DefaultDbSource } from './sources/default-db.source';
import { StreamController } from './stream.controller';
import { LocalFileSource } from './sources/local-file.source';
import { JikanSource } from './sources/jikan.source';
import { AnimeUnitySource } from './sources/animeunity.source';
import { AnimeUnityController } from './animeunity.controller';
import { HiAnimeSource } from './sources/hianime.source';
import { HiAnimeController } from './hianime.controller';
import { AnimeStreamingService } from '../services/anime-streaming.service';

@Module({
  imports: [TypeOrmModule.forFeature([Anime, Episode]), HttpModule],
  controllers: [AnimeController, StreamController, AnimeUnityController, HiAnimeController],
  providers: [
    AnimeService,
    SourceManager,
    DefaultDbSource,
    LocalFileSource,
    JikanSource,
    AnimeUnitySource,
    HiAnimeSource,
    AnimeStreamingService,
  ],
  exports: [AnimeService, SourceManager, AnimeUnitySource, HiAnimeSource, AnimeStreamingService],
})
export class AnimeModule { }

