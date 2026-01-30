import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from '../entities/user.entity';
import { UserPreference } from '../entities/user-preference.entity';
import { Watchlist } from '../entities/watchlist.entity';
import { WatchHistory } from '../entities/watch-history.entity';
import { Episode } from '../entities/episode.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      UserPreference,
      Watchlist,
      WatchHistory,
      Episode,
    ]),
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
