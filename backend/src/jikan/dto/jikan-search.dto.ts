import { IsOptional, IsString, IsInt, Min, Max, IsEnum } from 'class-validator';
import { Type } from 'class-transformer';

export enum JikanMangaType {
    MANGA = 'manga',
    NOVEL = 'novel',
    LIGHTNOVEL = 'lightnovel',
    ONESHOT = 'oneshot',
    DOUJIN = 'doujin',
    MANHWA = 'manhwa',
    MANHUA = 'manhua',
}

export enum JikanMangaStatus {
    PUBLISHING = 'publishing',
    COMPLETE = 'complete',
    HIATUS = 'hiatus',
    DISCONTINUED = 'discontinued',
    UPCOMING = 'upcoming',
}

export enum JikanMangaOrderBy {
    MAL_ID = 'mal_id',
    TITLE = 'title',
    START_DATE = 'start_date',
    END_DATE = 'end_date',
    CHAPTERS = 'chapters',
    VOLUMES = 'volumes',
    SCORE = 'score',
    SCORED_BY = 'scored_by',
    RANK = 'rank',
    POPULARITY = 'popularity',
    MEMBERS = 'members',
    FAVORITES = 'favorites',
}

export enum JikanSort {
    ASC = 'asc',
    DESC = 'desc',
}

export class JikanSearchQueryDto {
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
    @IsEnum(JikanMangaType)
    type?: JikanMangaType;

    @IsOptional()
    @IsEnum(JikanMangaStatus)
    status?: JikanMangaStatus;

    @IsOptional()
    @IsString()
    genres?: string; // Comma-separated genre IDs

    @IsOptional()
    @IsEnum(JikanMangaOrderBy)
    order_by?: JikanMangaOrderBy;

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

export class JikanTopMangaQueryDto {
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
    @IsEnum(JikanMangaType)
    type?: JikanMangaType;

    @IsOptional()
    @IsString()
    filter?: string; // publishing, upcoming, bypopularity, favorite
}
