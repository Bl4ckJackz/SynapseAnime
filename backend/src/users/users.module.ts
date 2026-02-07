import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from '../entities/user.entity';
import { UserPreference } from '../entities/user-preference.entity';
import { Watchlist } from '../entities/watchlist.entity';
import { WatchHistory } from '../entities/watch-history.entity';
import { Episode } from '../entities/episode.entity';
import { Anime } from '../entities/anime.entity';
import { AnimeModule } from '../anime/anime.module';
import { MangaModule } from '../manga/manga.module';
import { HistoryGateway } from './history.gateway';
import { JwtService } from '@nestjs/jwt';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      UserPreference,
      Watchlist,
      WatchHistory,
      Episode,
      WatchHistory,
      Episode,
      Anime,
    ]),
    AnimeModule,
    MangaModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: configService.get<string>('JWT_EXPIRES_IN', '7d') as any,
        },
      }),
    }),
    ConfigModule,
  ],
  controllers: [UsersController],
  providers: [UsersService, HistoryGateway],
  exports: [UsersService],
})
export class UsersModule { }
