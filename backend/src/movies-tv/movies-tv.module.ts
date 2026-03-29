import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { CommonModule } from '../common/common.module';
import { TmdbService } from './tmdb.service';
import { VidsrcSource } from './vidsrc.source';
import { MoviesTvService } from './movies-tv.service';
import { MoviesTvController } from './movies-tv.controller';

@Module({
  imports: [HttpModule, CommonModule],
  controllers: [MoviesTvController],
  providers: [TmdbService, VidsrcSource, MoviesTvService],
  exports: [TmdbService, VidsrcSource, MoviesTvService],
})
export class MoviesTvModule {}
