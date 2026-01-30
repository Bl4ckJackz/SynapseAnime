import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JikanMangaService } from './jikan-manga.service';
import { RateLimiterService } from '../common/services/rate-limiter.service';
import { CacheService } from '../common/services/cache.service';
import { CircuitBreakerService } from '../common/services/circuit-breaker.service';
import axios from 'axios';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('JikanMangaService', () => {
    let service: JikanMangaService;
    let cacheService: jest.Mocked<CacheService>;
    let circuitBreaker: jest.Mocked<CircuitBreakerService>;

    const mockAxiosInstance = {
        get: jest.fn(),
        interceptors: {
            request: { use: jest.fn(), eject: jest.fn() },
            response: { use: jest.fn(), eject: jest.fn() },
        },
    };

    beforeEach(async () => {
        mockedAxios.create.mockReturnValue(mockAxiosInstance as any);

        const module: TestingModule = await Test.createTestingModule({
            providers: [
                JikanMangaService,
                {
                    provide: ConfigService,
                    useValue: {
                        get: jest.fn().mockReturnValue('https://api.jikan.moe/v4'),
                    },
                },
                {
                    provide: RateLimiterService,
                    useValue: {
                        acquireToken: jest.fn().mockResolvedValue(undefined),
                    },
                },
                {
                    provide: CacheService,
                    useValue: {
                        get: jest.fn(),
                        getWithEtag: jest.fn().mockReturnValue({ data: null }),
                        set: jest.fn(),
                        updateExpiry: jest.fn(),
                    },
                },
                {
                    provide: CircuitBreakerService,
                    useValue: {
                        execute: jest.fn().mockImplementation((name, operation) => operation()),
                    },
                },
            ],
        }).compile();

        service = module.get<JikanMangaService>(JikanMangaService);
        cacheService = module.get(CacheService);
        circuitBreaker = module.get(CircuitBreakerService);
    });

    afterEach(() => {
        jest.clearAllMocks();
    });

    describe('searchManga', () => {
        it('should return cached data if available', async () => {
            const mockCachedData = { data: [], pagination: {} };
            cacheService.get.mockReturnValue(mockCachedData);

            const result = await service.searchManga({ q: 'naruto' });

            expect(cacheService.get).toHaveBeenCalled();
            expect(mockAxiosInstance.get).not.toHaveBeenCalled();
            expect(result).toEqual(mockCachedData);
        });

        it('should fetch from API if not cached', async () => {
            cacheService.get.mockReturnValue(null);
            const mockApiResponse = {
                data: {
                    data: [
                        {
                            mal_id: 1,
                            title: 'Naruto',
                            images: { jpg: { large_image_url: 'url' } },
                            authors: [],
                            genres: [],
                            themes: [],
                        },
                    ],
                    pagination: {
                        current_page: 1,
                        last_visible_page: 1,
                        has_next_page: false,
                        items: { total: 1, per_page: 25 },
                    },
                },
            };
            mockAxiosInstance.get.mockResolvedValue(mockApiResponse);

            const result = await service.searchManga({ q: 'naruto' });

            expect(mockAxiosInstance.get).toHaveBeenCalledWith('/manga', {
                params: { q: 'naruto' },
            });
            expect(result.data).toHaveLength(1);
            expect(result.data[0].title).toBe('Naruto');
            expect(cacheService.set).toHaveBeenCalled();
        });
    });

    describe('getMangaById', () => {
        it('should fetch manga details successfully', async () => {
            cacheService.get.mockReturnValue(null);
            const mockApiResponse = {
                data: {
                    data: {
                        mal_id: 1,
                        title: 'Naruto',
                        images: { jpg: { large_image_url: 'url' } },
                        authors: [],
                        genres: [],
                        themes: [],
                    },
                },
            };
            mockAxiosInstance.get.mockResolvedValue(mockApiResponse);

            const result = await service.getMangaById(1);

            expect(mockAxiosInstance.get).toHaveBeenCalledWith('/manga/1/full');
            expect(result.title).toBe('Naruto');
        });
    });

});
