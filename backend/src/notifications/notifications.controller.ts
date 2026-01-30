import {
  Controller,
  Get,
  Put,
  Post,
  Delete,
  Body,
  UseGuards,
} from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { User } from '../entities/user.entity';
import { UpdateNotificationSettingsDto } from './dto/update-notification-settings.dto';
import { RegisterFcmTokenDto } from './dto/register-fcm-token.dto';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get('settings')
  async getSettings(@CurrentUser() user: User) {
    return this.notificationsService.getSettings(user.id);
  }

  @Put('settings')
  async updateSettings(
    @CurrentUser() user: User,
    @Body() dto: UpdateNotificationSettingsDto,
  ) {
    return this.notificationsService.updateSettings(user.id, dto);
  }

  @Post('register-token')
  async registerToken(
    @CurrentUser() user: User,
    @Body() dto: RegisterFcmTokenDto,
  ) {
    await this.notificationsService.registerFcmToken(user.id, dto.fcmToken);
    return { success: true };
  }

  @Delete('unregister-token')
  async unregisterToken(@CurrentUser() user: User) {
    await this.notificationsService.unregisterFcmToken(user.id);
    return { success: true };
  }
}
