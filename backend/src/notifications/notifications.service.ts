import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NotificationSettings } from '../entities/notification-settings.entity';
import { User } from '../entities/user.entity';
import { UpdateNotificationSettingsDto } from './dto/update-notification-settings.dto';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(NotificationSettings)
    private settingsRepository: Repository<NotificationSettings>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async getSettings(userId: string): Promise<NotificationSettings> {
    let settings = await this.settingsRepository.findOne({
      where: { userId },
    });

    if (!settings) {
      // Create default settings
      settings = this.settingsRepository.create({
        userId,
        globalEnabled: true,
        animeSettings: JSON.stringify({}),
      });
      await this.settingsRepository.save(settings);
    }

    return settings;
  }

  async updateSettings(
    userId: string,
    dto: UpdateNotificationSettingsDto,
  ): Promise<NotificationSettings> {
    let settings = await this.settingsRepository.findOne({
      where: { userId },
    });

    if (!settings) {
      settings = this.settingsRepository.create({
        userId,
        animeSettings: JSON.stringify({}),
      });
    }

    if (dto.globalEnabled !== undefined) {
      settings.globalEnabled = dto.globalEnabled;
    }

    if (dto.animeId && dto.animeEnabled !== undefined) {
      // Parse existing settings, update, then stringify again
      const parsedSettings = settings.animeSettings
        ? JSON.parse(settings.animeSettings)
        : {};
      parsedSettings[dto.animeId] = dto.animeEnabled;
      settings.animeSettings = JSON.stringify(parsedSettings);
    }

    return this.settingsRepository.save(settings);
  }

  async registerFcmToken(userId: string, fcmToken: string): Promise<void> {
    await this.userRepository.update({ id: userId }, { fcmToken: fcmToken });
  }

  async unregisterFcmToken(userId: string): Promise<void> {
    await this.userRepository.update({ id: userId }, { fcmToken: '' });
  }
}
