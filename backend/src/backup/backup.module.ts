import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BackupService } from './backup.service';
import { WatchHistory } from '../entities/watch-history.entity';
import { User } from '../entities/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([WatchHistory, User])],
  providers: [BackupService],
  exports: [BackupService],
})
export class BackupModule {}
