import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DownloadController } from './download.controller';
import { DownloadService } from './download.service';
import { Download } from '../entities/download.entity';
import { DownloadSettings } from '../entities/download-settings.entity';
import { AnimeModule } from '../anime/anime.module';
import { LibraryModule } from '../library/library.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Download, DownloadSettings]),
    AnimeModule,
    LibraryModule,
  ],
  controllers: [DownloadController],
  providers: [DownloadService],
  exports: [DownloadService],
})
export class DownloadModule { }
