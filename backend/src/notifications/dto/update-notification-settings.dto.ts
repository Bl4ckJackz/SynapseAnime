import { IsBoolean, IsOptional, IsString, IsUUID } from 'class-validator';

export class UpdateNotificationSettingsDto {
  @IsOptional()
  @IsBoolean()
  globalEnabled?: boolean;

  @IsOptional()
  @IsUUID()
  animeId?: string;

  @IsOptional()
  @IsBoolean()
  animeEnabled?: boolean;
}
