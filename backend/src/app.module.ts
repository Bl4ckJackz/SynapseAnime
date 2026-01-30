import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
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


@Module({
  imports: [
    // Load environment variables
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),

    // Database connection
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'sqlite', // Changed to SQLite for easier local development
        database: './anime_player.db', // SQLite database file
        entities: [__dirname + '/**/*.entity{.ts,.js}'],
        synchronize: true, // Disable in production
        logging: process.env.NODE_ENV !== 'production',
      }),
    }),

    // Scheduler for notifications
    ScheduleModule.forRoot(),

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
  ],
  controllers: [
    AppController,
    AdController,
    NewsController,
  ],
  providers: [
    AppService,
  ],
})
export class AppModule { }
