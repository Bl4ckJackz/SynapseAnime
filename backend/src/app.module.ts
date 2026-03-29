import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { BackupModule } from './backup/backup.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { AnimeModule } from './anime/anime.module';
import { UsersModule } from './users/users.module';
import { AiModule } from './ai/ai.module';
import { NotificationsModule } from './notifications/notifications.module';
import { MangaModule } from './manga/manga.module';
import { MonetizationModule } from './monetization/monetization.module';
import { AdController } from './controllers/ad.controller';
import { NewsController } from './controllers/news.controller';
import { CommonModule } from './common/common.module';
import { JikanModule } from './jikan/jikan.module';
import { MangaHookModule } from './mangahook/mangahook.module';
import { CoreModule } from './core/core.module';
import { LibraryModule } from './library/library.module';
import { DownloadModule } from './download/download.module';
import { CommentsModule } from './comments/comments.module';
import { MoviesTvModule } from './movies-tv/movies-tv.module';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';

@Module({
  imports: [
    // Load environment variables
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),

    // Rate limiting
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 60 }]),

    // Database connection
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const isPostgres = configService.get<string>('DB_TYPE') === 'postgres';
        return {
          type: isPostgres ? 'postgres' : 'sqlite',
          database: isPostgres
            ? configService.get<string>('DB_DATABASE')
            : './anime_player.db',
          host: isPostgres ? configService.get<string>('DB_HOST') : undefined,
          port: isPostgres
            ? parseInt(configService.get<string>('DB_PORT') || '5432')
            : undefined,
          username: isPostgres
            ? configService.get<string>('DB_USERNAME')
            : undefined,
          password: isPostgres
            ? configService.get<string>('DB_PASSWORD')
            : undefined,
          entities: [__dirname + '/**/*.entity{.ts,.js}'],
          // autoLoadEntities: true,
          synchronize: process.env.NODE_ENV !== 'production',
          logging: process.env.NODE_ENV !== 'production',
        };
      },
    }),

    // Scheduler for notifications
    ScheduleModule.forRoot(),

    // Core module (shared dependencies)
    CoreModule,

    // Feature modules
    CommonModule,
    AuthModule,
    AnimeModule,
    UsersModule,
    AiModule,
    NotificationsModule,
    MangaModule,
    MonetizationModule,
    JikanModule,
    MangaHookModule,
    BackupModule,
    LibraryModule,
    DownloadModule,
    CommentsModule,
    MoviesTvModule,
    ServeStaticModule.forRoot({
      rootPath: join(process.cwd(), 'video_library'),
      serveRoot: '/downloads',
    }),
  ],
  controllers: [AppController, AdController, NewsController],
  providers: [AppService],
})
export class AppModule {}
