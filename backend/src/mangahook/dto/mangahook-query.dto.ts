import { IsOptional, IsString, IsInt, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class MangaHookListQueryDto {
    @IsOptional()
    @IsInt()
    @Min(1)
    @Type(() => Number)
    page?: number = 1;

    @IsOptional()
    @IsString()
    type?: string = 'newest'; // 'newest', 'latest', 'topview'

    @IsOptional()
    @IsString()
    category?: string = 'all';

    @IsOptional()
    @IsString()
    state?: string; // 'Completed', 'Ongoing'
}

export class MangaHookSearchQueryDto {
    @IsString()
    q: string;

    @IsOptional()
    @IsInt()
    @Min(1)
    @Type(() => Number)
    page?: number = 1;
}
