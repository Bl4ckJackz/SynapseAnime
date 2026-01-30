import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { SchedulerService } from './scheduler.service';
import { FcmService } from './fcm.service';
import { NotificationSettings } from '../entities/notification-settings.entity';
import { ReleaseSchedule } from '../entities/release-schedule.entity';
import { User } from '../entities/user.entity';
import { Anime } from '../entities/anime.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      NotificationSettings,
      ReleaseSchedule,
      User,
      Anime,
    ]),
  ],
  controllers: [NotificationsController],
  providers: [NotificationsService, SchedulerService, FcmService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
