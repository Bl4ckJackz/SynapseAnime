// Jikan API Manga Response DTOs
// Based on Jikan API v4 documentation

export interface JikanPagination {
    last_visible_page: number;
    has_next_page: boolean;
    current_page: number;
    items: {
        count: number;
        total: number;
        per_page: number;
    };
}

export interface JikanImage {
    image_url: string;
    small_image_url: string;
    large_image_url: string;
}

export interface JikanImages {
    jpg: JikanImage;
    webp?: JikanImage;
}

export interface JikanDateProp {
    day: number | null;
    month: number | null;
    year: number | null;
}

export interface JikanPublished {
    from: string | null;
    to: string | null;
    prop: {
        from: JikanDateProp;
        to: JikanDateProp;
    };
    string: string;
}

export interface JikanMalEntity {
    mal_id: number;
    type: string;
    name: string;
    url: string;
}

export interface JikanManga {
    mal_id: number;
    url: string;
    images: JikanImages;
    approved: boolean;
    titles: Array<{ type: string; title: string }>;
    title: string;
    title_english: string | null;
    title_japanese: string | null;
    title_synonyms: string[];
    type: string | null;
    chapters: number | null;
    volumes: number | null;
    status: string;
    publishing: boolean;
    published: JikanPublished;
    score: number | null;
    scored: number | null;
    scored_by: number | null;
    rank: number | null;
    popularity: number | null;
    members: number | null;
    favorites: number | null;
    synopsis: string | null;
    background: string | null;
    authors: JikanMalEntity[];
    serializations: JikanMalEntity[];
    genres: JikanMalEntity[];
    explicit_genres: JikanMalEntity[];
    themes: JikanMalEntity[];
    demographics: JikanMalEntity[];
}

export interface JikanMangaResponse {
    data: JikanManga;
}

export interface JikanMangaListResponse {
    pagination: JikanPagination;
    data: JikanManga[];
}

export interface JikanCharacter {
    mal_id: number;
    url: string;
    images: JikanImages;
    name: string;
    role: string;
}

export interface JikanCharactersResponse {
    data: JikanCharacter[];
}

export interface JikanStatistics {
    reading: number;
    completed: number;
    on_hold: number;
    dropped: number;
    plan_to_read: number;
    total: number;
    scores: Array<{
        score: number;
        votes: number;
        percentage: number;
    }>;
}

export interface JikanStatisticsResponse {
    data: JikanStatistics;
}

export interface JikanRecommendation {
    entry: {
        mal_id: number;
        url: string;
        images: JikanImages;
        title: string;
    };
    votes: number;
}

export interface JikanRecommendationsResponse {
    data: JikanRecommendation[];
}

// Transformed DTOs for frontend consumption
export interface MangaDto {
    malId: number;
    url: string;
    title: string;
    titleEnglish: string | null;
    titleJapanese: string | null;
    imageUrl: string;
    type: string | null;
    chapters: number | null;
    volumes: number | null;
    status: string;
    publishing: boolean;
    score: number | null;
    rank: number | null;
    popularity: number | null;
    synopsis: string | null;
    authors: string[];
    genres: string[];
    themes: string[];
}

export interface MangaListDto {
    data: MangaDto[];
    pagination: {
        currentPage: number;
        lastPage: number;
        hasNextPage: boolean;
        totalItems: number;
        itemsPerPage: number;
    };
}

// Transform function
export function transformJikanManga(manga: JikanManga): MangaDto {
    return {
        malId: manga.mal_id,
        url: manga.url,
        title: manga.title,
        titleEnglish: manga.title_english,
        titleJapanese: manga.title_japanese,
        imageUrl: manga.images.jpg.large_image_url || manga.images.jpg.image_url,
        type: manga.type,
        chapters: manga.chapters,
        volumes: manga.volumes,
        status: manga.status,
        publishing: manga.publishing,
        score: manga.score,
        rank: manga.rank,
        popularity: manga.popularity,
        synopsis: manga.synopsis,
        authors: manga.authors.map(a => a.name),
        genres: manga.genres.map(g => g.name),
        themes: manga.themes.map(t => t.name),
    };
}

export function transformJikanMangaList(response: JikanMangaListResponse): MangaListDto {
    return {
        data: response.data.map(transformJikanManga),
        pagination: {
            currentPage: response.pagination.current_page,
            lastPage: response.pagination.last_visible_page,
            hasNextPage: response.pagination.has_next_page,
            totalItems: response.pagination.items.total,
            itemsPerPage: response.pagination.items.per_page,
        },
    };
}
