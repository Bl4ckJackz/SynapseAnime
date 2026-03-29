import {
  IsString,
  IsNumber,
  IsOptional,
  IsUrl,
  Min,
  MaxLength,
  IsBoolean,
} from 'class-validator';

export class DownloadUrlDto {
  @IsUrl({}, { message: 'A valid URL is required' })
  url: string;

  @IsString()
  @MaxLength(200)
  animeName: string;

  @IsNumber()
  @Min(0)
  episodeNumber: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  episodeTitle?: string;
}

export class UpdateDownloadSettingsDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  downloadPath?: string;

  @IsOptional()
  @IsBoolean()
  useServerFolder?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  serverFolderPath?: string;
}
