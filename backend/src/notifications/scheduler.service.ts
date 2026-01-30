import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThanOrEqual } from 'typeorm';
import { ReleaseSchedule } from '../entities/release-schedule.entity';
import { NotificationSettings } from '../entities/notification-settings.entity';
import { User } from '../entities/user.entity';
import { Anime } from '../entities/anime.entity';
import { FcmService } from './fcm.service';

@Injectable()
export class SchedulerService {
  private readonly logger = new Logger(SchedulerService.name);

  constructor(
    @InjectRepository(ReleaseSchedule)
    private scheduleRepository: Repository<ReleaseSchedule>,
    @InjectRepository(NotificationSettings)
    private notificationSettingsRepository: Repository<NotificationSettings>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Anime)
    private animeRepository: Repository<Anime>,
    private fcmService: FcmService,
  ) {}

  // Run every 15 minutes
  @Cron(CronExpression.EVERY_10_MINUTES)
  async checkNewReleases() {
    this.logger.log('Checking for new anime releases...');

    const now = new Date();

    // Find schedules that are due and not yet notified
    const dueSchedules = await this.scheduleRepository.find({
      where: {
        releaseDate: LessThanOrEqual(now),
        notified: false,
      },
      relations: ['anime'],
    });

    if (dueSchedules.length === 0) {
      this.logger.log('No new releases to notify about');
      return;
    }

    for (const schedule of dueSchedules) {
      await this.notifyUsersAboutRelease(schedule);

      // Mark as notified
      schedule.notified = true;
      await this.scheduleRepository.save(schedule);
    }

    this.logger.log(`Processed ${dueSchedules.length} release notifications`);
  }

  private async notifyUsersAboutRelease(schedule: ReleaseSchedule) {
    const anime = await this.animeRepository.findOne({
      where: { id: schedule.animeId },
    });

    if (!anime) return;

    // Find all users with notifications enabled for this anime
    const settings = await this.notificationSettingsRepository.find({
      where: { globalEnabled: true },
    });

    const userIds = settings
      .filter((s) => {
        // Check if notifications are enabled for this specific anime
        // or if no specific settings exist (default: enabled)
        const animeSpecific = s.animeSettings?.[anime.id];
        return animeSpecific !== false;
      })
      .map((s) => s.userId);

    if (userIds.length === 0) return;

    // Get users with FCM tokens
    const users = await this.userRepository
      .createQueryBuilder('user')
      .where('user.id IN (:...userIds)', { userIds })
      .andWhere('user.fcmToken IS NOT NULL')
      .getMany();

    const fcmTokens = users
      .map((u) => u.fcmToken)
      .filter((token): token is string => !!token);

    if (fcmTokens.length === 0) return;

    // Send notifications
    const notification = {
      title: `🎬 Nuovo episodio disponibile!`,
      body: `${anime.title} - Episodio ${schedule.episodeNumber} è ora disponibile`,
      data: {
        animeId: anime.id,
        episodeNumber: String(schedule.episodeNumber),
      },
    };

    const sent = await this.fcmService.sendToMultiple(fcmTokens, notification);
    this.logger.log(
      `Sent ${sent} notifications for ${anime.title} Ep.${schedule.episodeNumber}`,
    );
  }
}
