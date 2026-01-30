import { IsString, IsNumber, IsUUID } from 'class-validator';

export class UpdateProgressDto {
  @IsString()
  episodeId: string;

  @IsNumber()
  progressSeconds: number;
}
