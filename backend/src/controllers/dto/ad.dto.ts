import {
  IsString,
  IsOptional,
  IsIn,
  IsDateString,
  MaxLength,
} from 'class-validator';

export class CreateAdDto {
  @IsString()
  @MaxLength(200)
  title: string;

  @IsString()
  @MaxLength(5000)
  content: string;

  @IsString()
  @MaxLength(200)
  advertiser: string;

  @IsString()
  @MaxLength(50)
  adType: string;

  @IsIn(['all', 'free_users', 'premium_users'])
  targetAudience: 'all' | 'free_users' | 'premium_users';

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;
}

export class TrackImpressionDto {
  @IsString()
  adId: string;

  @IsString()
  sessionId: string;

  @IsOptional()
  durationWatched?: number;
}
