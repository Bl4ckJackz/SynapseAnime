import { IsOptional, IsArray, IsString } from 'class-validator';

export class UpdatePreferencesDto {
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  preferredLanguages?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  preferredGenres?: string[];
}
