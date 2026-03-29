import {
  IsString,
  IsOptional,
  MaxLength,
  IsUrl,
  IsArray,
} from 'class-validator';

export class CreateNewsDto {
  @IsString()
  @MaxLength(300)
  title: string;

  @IsString()
  @MaxLength(10000)
  content: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;

  @IsOptional()
  @IsString()
  source?: 'myanimelist' | 'anilist' | 'custom';

  @IsOptional()
  @IsUrl()
  imageUrl?: string;

  @IsOptional()
  @IsUrl()
  sourceUrl?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];
}
