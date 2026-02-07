import { IsString, IsNumber, IsUUID, IsOptional } from 'class-validator';

export class UpdateProgressDto {
  @IsString()
  episodeId: string;

  @IsNumber()
  progressSeconds: number;

  // Metadata for lazy creation
  @IsString()
  @IsOptional()
  animeId?: string;

  @IsString()
  @IsOptional()
  animeTitle?: string;

  @IsString()
  @IsOptional()
  animeCover?: string;

  @IsNumber()
  @IsOptional()
  animeTotalEpisodes?: number;

  @IsNumber()
  @IsOptional()
  episodeNumber?: number;

  @IsString()
  @IsOptional()
  episodeTitle?: string;

  @IsString()
  @IsOptional()
  episodeThumbnail?: string;

  @IsNumber()
  @IsOptional()
  duration?: number;
}
