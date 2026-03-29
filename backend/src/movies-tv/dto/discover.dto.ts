import { IsOptional, IsInt, Min, Max, IsString } from 'class-validator';
import { Type } from 'class-transformer';

export class DiscoverDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Type(() => Number)
  page?: number = 1;

  @IsOptional()
  @IsString()
  with_genres?: string; // Comma-separated genre IDs

  @IsOptional()
  @IsInt()
  @Min(1900)
  @Max(2100)
  @Type(() => Number)
  year?: number;

  @IsOptional()
  @IsString()
  sort_by?: string; // e.g. 'popularity.desc', 'vote_average.desc'

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10)
  @Type(() => Number)
  vote_average_gte?: number;

  @IsOptional()
  @IsString()
  language?: string;
}
