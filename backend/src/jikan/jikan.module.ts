import { Module } from '@nestjs/common';
import { CommonModule } from '../common/common.module';
import { JikanMangaService } from './jikan-manga.service';
import { JikanMangaController } from './jikan-manga.controller';
import { JikanAnimeService } from './jikan-anime.service';
import { JikanAnimeController } from './jikan-anime.controller';

@Module({
    imports: [CommonModule],
    controllers: [JikanMangaController, JikanAnimeController],
    providers: [JikanMangaService, JikanAnimeService],
    exports: [JikanMangaService, JikanAnimeService],
})
export class JikanModule { }
