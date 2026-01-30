import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { Anime, AnimeStatus } from '../../entities/anime.entity';
import { Episode } from '../../entities/episode.entity';
import {
    AnimeSource,
    AnimeFilters,
    PaginatedResult,
} from './anime-source.interface';

@Injectable()
export class HiAnimeSource implements AnimeSource {
    readonly id = 'hianime';
    readonly name = 'HiAnime (aniwatch-api)';
    readonly description = 'Streaming from HiAnime via aniwatch-api with reliable M3U8 streams';
    readonly hasDirectStream = true;

    // Public aniwatch-api instance
    private readonly baseUrl = process.env.HIANIME_API_URL || 'https://aniwatch-api-dusky.vercel.app/api/v2/hianime';

    constructor(private readonly httpService: HttpService) { }

    async getAnimeList(filters: AnimeFilters): Promise<PaginatedResult<Anime>> {
        try {
            let searchQuery = filters.search;
            if (!searchQuery) {
                switch (filters.filter) {
                    case 'new':
                        searchQuery = 'new';
                        break;
                    case 'airing':
                        searchQuery = 'airing';
                        break;
                    case 'favorite':
                        searchQuery = 'best';
                        break;
                    default:
                        searchQuery = 'popular';
                }
            }

            const response = await this.httpService.axiosRef.get(
                `${this.baseUrl}/search?q=${encodeURIComponent(searchQuery)}&page=${filters.page || 1}`,
                { timeout: 15000 }
            );

            const data = response.data;
            if (!data.success || !data.data?.animes) {
                return { data: [], total: 0, page: 1, limit: 20, totalPages: 0 };
            }

            const animes: Anime[] = data.data.animes.map((item: any) => ({
                id: item.id,
                title: item.name,
                coverUrl: item.poster,
                description: '',
                genres: [],
                status: AnimeStatus.ONGOING,
                releaseYear: 0,
                rating: 0,
                totalEpisodes: item.episodes?.sub || item.episodes?.dub || 0,
            } as any as Anime));

            return {
                data: animes,
                total: animes.length,
                page: data.data.currentPage || 1,
                limit: 20,
                totalPages: data.data.totalPages || 1,
            };
        } catch (error) {
            console.error('[HiAnime] Search failed:', error.message);
            return { data: [], total: 0, page: 1, limit: 20, totalPages: 0 };
        }
    }

    async getAnimeById(id: string): Promise<Anime | null> {
        try {
            const response = await this.httpService.axiosRef.get(
                `${this.baseUrl}/anime/${encodeURIComponent(id)}`,
                { timeout: 15000 }
            );

            const data = response.data;
            if (!data.success || !data.data?.anime) {
                return null;
            }

            const anime = data.data.anime;
            const info = anime.info;
            const moreInfo = anime.moreInfo;

            return {
                id: info.id,
                title: info.name,
                coverUrl: info.poster,
                description: info.description || '',
                genres: moreInfo?.genres || [],
                status: moreInfo?.status === 'Finished Airing' ? AnimeStatus.COMPLETED : AnimeStatus.ONGOING,
                releaseYear: moreInfo?.aired ? parseInt(moreInfo.aired.split(' ').pop()) || 0 : 0,
                rating: info.stats?.rating || 0,
                totalEpisodes: info.stats?.episodes?.sub || info.stats?.episodes?.dub || 0,
            } as any as Anime;
        } catch (error) {
            console.error('[HiAnime] Get anime failed:', error.message);
            return null;
        }
    }

    async getEpisodes(animeId: string): Promise<Episode[]> {
        try {
            const response = await this.httpService.axiosRef.get(
                `${this.baseUrl}/anime/${encodeURIComponent(animeId)}/episodes`,
                { timeout: 15000 }
            );

            const data = response.data;
            if (!data.success || !data.data?.episodes) {
                return [];
            }

            return data.data.episodes.map((ep: any) => ({
                id: ep.episodeId,
                animeId,
                number: ep.number,
                title: ep.title || `Episode ${ep.number}`,
                duration: 0,
                thumbnail: null,
                streamUrl: '', // Will be fetched when watching
                isFiller: ep.isFiller || false,
            } as unknown as Episode));
        } catch (error) {
            console.error('[HiAnime] Get episodes failed:', error.message);
            return [];
        }
    }

    async getStreamUrl(episodeId: string): Promise<string> {
        try {
            // Try sub first, then dub
            const servers = ['hd-1', 'hd-2', 'megacloud'];

            for (const server of servers) {
                try {
                    const url = `${this.baseUrl}/episode/sources?animeEpisodeId=${encodeURIComponent(episodeId)}&server=${server}&category=sub`;
                    console.log(`[HiAnime] Requesting: ${url}`);
                    const response = await this.httpService.axiosRef.get(url, { timeout: 20000 });

                    const data = response.data;
                    if (data.success && data.data?.sources?.length > 0) {
                        // Return the first valid source URL
                        const source = data.data.sources[0];
                        console.log('[HiAnime] Found stream URL:', source.url);
                        return source.url;
                    } else {
                        console.log(`[HiAnime] Server ${server} returned no sources. Success: ${data.success}`);
                    }
                } catch (serverError) {
                    console.log(`[HiAnime] Server ${server} failed, trying next...`);
                }
            }

            // Try dub if sub failed
            for (const server of servers) {
                try {
                    const response = await this.httpService.axiosRef.get(
                        `${this.baseUrl}/episode/sources?animeEpisodeId=${encodeURIComponent(episodeId)}&server=${server}&category=dub`,
                        { timeout: 20000 }
                    );

                    const data = response.data;
                    if (data.success && data.data?.sources?.length > 0) {
                        return data.data.sources[0].url;
                    }
                } catch (serverError) {
                    // Continue to next server
                }
            }

            console.log('[HiAnime] No stream sources found');
            return '';
        } catch (error) {
            console.error('[HiAnime] Get stream URL failed:', error.message);
            return '';
        }
    }

    private mapStatus(status: string): AnimeStatus {
        if (!status) return AnimeStatus.ONGOING;
        const lowerStatus = status.toLowerCase();
        if (lowerStatus.includes('complete') || lowerStatus.includes('finished')) {
            return AnimeStatus.COMPLETED;
        }
        return AnimeStatus.ONGOING;
    }
}
