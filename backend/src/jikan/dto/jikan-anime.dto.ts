import { IsOptional, IsString, IsInt, Min, Max, IsEnum } from 'class-validator';
import { Type } from 'class-transformer';

export enum JikanAnimeType {
    TV = 'tv',
    MOVIE = 'movie',
    OVA = 'ova',
    SPECIAL = 'special',
    ONA = 'ona',
    MUSIC = 'music',
}

export enum JikanAnimeStatus {
    AIRING = 'airing',
    COMPLETE = 'complete',
    UPCOMING = 'upcoming',
}

import { JikanSort } from './jikan-search.dto';

export enum JikanAnimeOrderBy {
    MAL_ID = 'mal_id',
    TITLE = 'title',
    START_DATE = 'start_date',
    END_DATE = 'end_date',
    EPISODES = 'episodes',
    SCORE = 'score',
    SCORED_BY = 'scored_by',
    RANK = 'rank',
    POPULARITY = 'popularity',
    MEMBERS = 'members',
    FAVORITES = 'favorites',
}

export class JikanAnimeSearchQueryDto {
    @IsOptional()
    @IsString()
    q?: string;

    @IsOptional()
    @IsInt()
    @Min(1)
    @Type(() => Number)
    page?: number = 1;

    @IsOptional()
    @IsInt()
    @Min(1)
    @Max(25)
    @Type(() => Number)
    limit?: number = 25;

    @IsOptional()
    @IsEnum(JikanAnimeType)
    type?: JikanAnimeType;

    @IsOptional()
    @IsEnum(JikanAnimeStatus)
    status?: JikanAnimeStatus;

    @IsOptional()
    @IsString()
    genres?: string; // Comma-separated genre IDs

    @IsOptional()
    @IsEnum(JikanAnimeOrderBy)
    order_by?: JikanAnimeOrderBy;

    @IsOptional()
    @IsEnum(JikanSort)
    sort?: JikanSort;

    @IsOptional()
    @IsInt()
    @Min(0)
    @Max(10)
    @Type(() => Number)
    min_score?: number;

    @IsOptional()
    @IsInt()
    @Min(0)
    @Max(10)
    @Type(() => Number)
    max_score?: number;

    @IsOptional()
    @IsString()
    sfw?: string; // 'true' or 'false'
}

export class JikanTopAnimeQueryDto {
    @IsOptional()
    @IsInt()
    @Min(1)
    @Type(() => Number)
    page?: number = 1;

    @IsOptional()
    @IsInt()
    @Min(1)
    @Max(25)
    @Type(() => Number)
    limit?: number = 25;

    @IsOptional()
    @IsEnum(JikanAnimeType)
    type?: JikanAnimeType;

    @IsOptional()
    @IsString()
    filter?: string; // airing, upcoming, bypopularity, favorite
}
