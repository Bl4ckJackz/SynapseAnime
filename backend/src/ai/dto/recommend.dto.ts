import { IsString, MinLength } from 'class-validator';

export class RecommendDto {
  @IsString()
  @MinLength(1)
  message: string;
}
