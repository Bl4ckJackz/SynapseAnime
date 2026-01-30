import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CacheService } from '../common/services/cache.service';
import { MangaDexService } from '../services/mangadex-api.service'; // Adjust import path if needed
import {
    MangaHookListQueryDto,
    MangaHookSearchQueryDto,
    MangaHookMangaListDto,
    MangaHookMangaDetailDto,
    MangaHookChapterDto,
} from './dto';

@Injectable()
export class MangaHookService {
    private readonly logger = new Logger(MangaHookService.name);
    // Categories mapping for MangaDex Tags
    private readonly categoryMap: Record<string, string> = {
        'action': '391b0423-d847-456f-aff0-8b0cfc03066b',
        'azione': '391b0423-d847-456f-aff0-8b0cfc03066b',
        'adventure': '87cc87cd-a395-47af-b27a-93258283bbc6',
        'avventura': '87cc87cd-a395-47af-b27a-93258283bbc6',
        'comedy': '4d32cc48-9f00-4cca-9b5a-a839f0764984',
        'commedia': '4d32cc48-9f00-4cca-9b5a-a839f0764984',
        'drama': 'b9af3a63-f058-46de-a9a0-e0c13906197a',
        'drammatico': 'b9af3a63-f058-46de-a9a0-e0c13906197a',
        'fantasy': 'cdc58593-87dd-415e-bbc0-2ec27bf404cc',
        'horror': 'cdad7e68-1419-41dd-bdce-27753074a640',
        'romance': '423e2eae-a7a2-4a8b-ac03-a8351462d71d',
        'romantico': '423e2eae-a7a2-4a8b-ac03-a8351462d71d',
        'scifi': '256c8bd9-4904-4360-bf4f-508a76d67183',
        'sci-fi': '256c8bd9-4904-4360-bf4f-508a76d67183',
        'fantascienza': '256c8bd9-4904-4360-bf4f-508a76d67183',
        'slice of life': 'e5301a23-ebd9-49dd-a0cb-2add944c7fe9',
        'vita quotidiana': 'e5301a23-ebd9-49dd-a0cb-2add944c7fe9',
        'isekai': 'ace04997-f6bd-436e-b261-779182193d3d',
        'mystery': 'ee968100-4191-4968-93d3-f82d72be7e46',
        'mistero': 'ee968100-4191-4968-93d3-f82d72be7e46',
        'psychological': '3b60b75c-a2d7-4860-ab56-05f391bb889c',
        'psicologico': '3b60b75c-a2d7-4860-ab56-05f391bb889c',
    };

    constructor(
        private readonly configService: ConfigService,
        private readonly cacheService: CacheService,
        private readonly mangaDexService: MangaDexService,
    ) { }

    async getMangaList(query: MangaHookListQueryDto): Promise<MangaHookMangaListDto> {
        const { page = 1, type = 'newest', category = 'all', state } = query;
        const cacheKey = `mangahook:list:${page}:${type}:${category}:${state || 'all'}`;

        const cached = this.cacheService.get<MangaHookMangaListDto>(cacheKey);
        if (cached) {
            return cached;
        }

        try {
            // Map filters to MangaDex params
            const filters: any = {
                limit: 20,
                offset: (page - 1) * 20,
                'availableTranslatedLanguages[]': ['it', 'en'],
            };

            // Map Sort Type
            if (type === 'newest') {
                filters['order[createdAt]'] = 'desc';
            } else if (type === 'latest') {
                filters['order[updatedAt]'] = 'desc';
            } else if (type === 'topview' || type === 'bypopularity') {
                filters['order[followedCount]'] = 'desc';
            } else {
                filters['order[latestUploadedChapter]'] = 'desc';
            }

            // Map Category (Genre)
            if (category && category.toLowerCase() !== 'all') {
                const tagId = this.findCategoryTag(category);
                if (tagId) {
                    filters['includedTags[]'] = [tagId];
                }
            }

            // Map State (Status)
            if (state && state.toLowerCase() !== 'all') {
                const status = state.toLowerCase();
                if (status === 'ongoing') filters['status[]'] = ['ongoing'];
                if (status === 'completed') filters['status[]'] = ['completed'];
                if (status === 'hiatus') filters['status[]'] = ['hiatus'];
            }

            const mangas = await this.mangaDexService.searchManga('', filters);

            const transformed: MangaHookMangaListDto = {
                data: mangas.map(m => ({
                    id: m.mangadexId, // UUID works for mobile app
                    title: m.title,
                    description: m.description,
                    imageUrl: m.coverImage,
                    latestChapter: 'N/A',
                    views: m.rating ? `${m.rating.toFixed(1)}/10` : 'N/A',
                })),
                pagination: {
                    totalItems: 10000,
                    totalPages: 500,
                    currentPage: page,
                },
                filters: {
                    types: [
                        { id: 'newest', label: 'Newest' },
                        { id: 'latest', label: 'Latest Update' },
                        { id: 'topview', label: 'Most Popular' }
                    ],
                    states: [
                        { id: 'all', label: 'All' },
                        { id: 'ongoing', label: 'Ongoing' },
                        { id: 'completed', label: 'Completed' }
                    ],
                    categories: Object.keys(this.categoryMap).map(k => ({
                        id: k,
                        label: k.charAt(0).toUpperCase() + k.slice(1)
                    })).concat([{ id: 'all', label: 'All' }]),
                }
            };

            this.cacheService.set(cacheKey, transformed, 'mangahook');
            return transformed;

        } catch (error) {
            this.logger.error('Error fetching manga list via MangaDex proxy:', error);
            throw new HttpException('Failed to fetch manga list', HttpStatus.BAD_GATEWAY);
        }
    }

    private findCategoryTag(category: string): string | undefined {
        const key = category.toLowerCase().trim();
        return this.categoryMap[key];
    }

    async searchManga(query: MangaHookSearchQueryDto): Promise<MangaHookMangaListDto> {
        // Implement search using getMangaList logic but with text query
        // Since getMangaList uses searchManga with empty string, we can do similar but pass query
        // However, we didn't implement strict query passing to getMangaList.
        // Let's call mangaDexService directly and map.

        try {
            const mangas = await this.mangaDexService.searchManga(query.q);

            const transformed: MangaHookMangaListDto = {
                data: mangas.map(m => ({
                    id: m.mangadexId,
                    title: m.title,
                    description: m.description,
                    imageUrl: m.coverImage,
                    latestChapter: 'N/A',
                    views: m.rating ? `${m.rating.toFixed(1)}/10` : 'N/A',
                })),
                pagination: {
                    totalItems: mangas.length,
                    totalPages: 1,
                    currentPage: 1,
                },
                filters: {
                    types: [], states: [], categories: []
                }
            };
            return transformed;
        } catch (error) {
            throw new HttpException('Search failed', HttpStatus.BAD_GATEWAY);
        }
    }

    async getMangaById(mangaId: string): Promise<MangaHookMangaDetailDto> {
        try {
            const manga = await this.mangaDexService.getMangaDetails(mangaId);
            return {
                id: manga.mangadexId,
                title: manga.title,
                description: manga.description,
                imageUrl: manga.coverImage,
                author: manga.authors.join(', '),
                status: manga.status,
                genres: manga.genres,
                views: 'N/A',
                updatedAt: manga.updatedAt.toString(),
                chapters: []
            };
        } catch (e) {
            throw new HttpException('Manga not found', HttpStatus.NOT_FOUND);
        }
    }

    async getChapterImages(mangaId: string, chapterId: string): Promise<MangaHookChapterDto> {
        try {
            const images = await this.mangaDexService.getChapterPages(chapterId);
            return {
                title: 'Chapter',
                pages: images
            };
        } catch (e) {
            throw new HttpException('Chapter pages not found', HttpStatus.NOT_FOUND);
        }
    }

    async getFilters(): Promise<{
        types: Array<{ id: string; label: string }>;
        states: Array<{ id: string; label: string }>;
        categories: Array<{ id: string; label: string }>;
    }> {
        // Return existing filters from a dummy list call or just hardcoded
        const list = await this.getMangaList({ page: 1 });
        return list.filters;
    }

    // Health check stub
    async checkHealth(): Promise<boolean> {
        return true;
    }
}
